locals {
  name_prefix = "${var.app_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Application = var.app_name
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
  })
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# ─────────────────────────────────────────────
# Spoke VPC (private subnets only — egress via TGW → hub NAT)
# ─────────────────────────────────────────────

resource "aws_vpc" "spoke" {
  cidr_block           = var.spoke_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(local.common_tags, { Name = "${local.name_prefix}-spoke-vpc" })
}

resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.spoke.id
  cidr_block        = cidrsubnet(var.spoke_vpc_cidr, 4, count.index)
  availability_zone = local.azs[count.index]
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${local.azs[count.index]}"
    Tier = "private"
  })
}

resource "aws_subnet" "tgw" {
  count             = var.az_count
  vpc_id            = aws_vpc.spoke.id
  cidr_block        = cidrsubnet(var.spoke_vpc_cidr, 4, count.index + var.az_count)
  availability_zone = local.azs[count.index]
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tgw-${local.azs[count.index]}"
    Tier = "transit"
  })
}

# TGW Attachment — connects spoke to hub
resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  subnet_ids         = aws_subnet.tgw[*].id
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.spoke.id

  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-tgw-attach" })
}

# Route Tables — all egress via TGW
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.spoke.id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-private-rt" })
}

resource "aws_route" "default_via_tgw" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id
  depends_on             = [aws_ec2_transit_gateway_vpc_attachment.spoke]
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs/${local.name_prefix}"
  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_iam_role" "flow_logs" {
  name = "${local.name_prefix}-flow-logs-role"
  tags = local.common_tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${local.name_prefix}-flow-logs"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup", "logs:CreateLogStream",
        "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "spoke" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.spoke.id
  tags            = merge(local.common_tags, { Name = "${local.name_prefix}-flow-log" })
}

# ─────────────────────────────────────────────
# Security Group — default deny, explicit allow
# ─────────────────────────────────────────────

resource "aws_default_security_group" "spoke" {
  vpc_id = aws_vpc.spoke.id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-default-sg-deny-all" })
  # No ingress/egress rules = deny all (overrides AWS default allow-all)
}

# ─────────────────────────────────────────────
# IAM Permission Boundary — limits blast radius per workload
# ─────────────────────────────────────────────

resource "aws_iam_policy" "permission_boundary" {
  name        = "${local.name_prefix}-permission-boundary"
  description = "Permission boundary for ${var.app_name} ${var.environment} roles"
  tags        = local.common_tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowWorkloadServices"
        Effect   = "Allow"
        Action   = ["s3:*", "dynamodb:*", "sqs:*", "sns:*", "lambda:*", "logs:*", "xray:*", "ssm:GetParameter*"]
        Resource = "*"
      },
      {
        Sid      = "DenyIAMEscalation"
        Effect   = "Deny"
        Action   = ["iam:CreateUser", "iam:DeleteUser", "iam:AttachUserPolicy", "iam:PutUserPolicy", "iam:CreateAccessKey"]
        Resource = "*"
      },
      {
        Sid      = "DenyNetworkChanges"
        Effect   = "Deny"
        Action   = ["ec2:DeleteVpc", "ec2:ModifyVpcAttribute", "ec2:DeleteSubnet", "ec2:DeleteRouteTable"]
        Resource = "*"
      }
    ]
  })
}
