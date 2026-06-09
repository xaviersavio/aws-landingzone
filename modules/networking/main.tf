terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

data "aws_availability_zones" "available" {
  state = "available"
}

# KMS key for VPC Flow Logs
resource "aws_kms_key" "flow_logs" {
  description             = "KMS key for VPC Flow Logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-flow-logs-key" })

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*",
          "kms:GenerateDataKey*", "kms:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "flow_logs" {
  name          = "alias/${var.name_prefix}-flow-logs"
  target_key_id = aws_kms_key.flow_logs.key_id
}

data "aws_caller_identity" "current" {}

# Hub VPC
resource "aws_vpc" "hub" {
  cidr_block           = var.hub_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, { Name = "${var.name_prefix}-hub-vpc" })
}

# Public subnets (NAT Gateways, ALBs)
resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.hub.id
  cidr_block              = cidrsubnet(var.hub_vpc_cidr, 4, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

# Private subnets (workloads, endpoints)
resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.hub.id
  cidr_block        = cidrsubnet(var.hub_vpc_cidr, 4, count.index + var.az_count)
  availability_zone = local.azs[count.index]
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-${local.azs[count.index]}"
    Tier = "private"
  })
}

# Transit subnets (TGW attachments)
resource "aws_subnet" "transit" {
  count             = var.az_count
  vpc_id            = aws_vpc.hub.id
  cidr_block        = cidrsubnet(var.hub_vpc_cidr, 4, count.index + var.az_count * 2)
  availability_zone = local.azs[count.index]
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-transit-${local.azs[count.index]}"
    Tier = "transit"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.hub.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count      = var.az_count
  domain     = "vpc"
  tags       = merge(var.tags, { Name = "${var.name_prefix}-nat-eip-${local.azs[count.index]}" })
  depends_on = [aws_internet_gateway.this]
}

# NAT Gateways (one per AZ for high availability)
resource "aws_nat_gateway" "this" {
  count         = var.az_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(var.tags, { Name = "${var.name_prefix}-natgw-${local.azs[count.index]}" })
  depends_on    = [aws_internet_gateway.this]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.hub.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Tables (per-AZ for NAT HA)
resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.hub.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-private-rt-${local.azs[count.index]}" })
}

resource "aws_route" "private_nat" {
  count                  = var.az_count
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# Transit Route Tables
resource "aws_route_table" "transit" {
  count  = var.az_count
  vpc_id = aws_vpc.hub.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-transit-rt-${local.azs[count.index]}" })
}

resource "aws_route_table_association" "transit" {
  count          = var.az_count
  subnet_id      = aws_subnet.transit[count.index].id
  route_table_id = aws_route_table.transit[count.index].id
}

# Transit Gateway
resource "aws_ec2_transit_gateway" "this" {
  description                     = "Central TGW for ${var.name_prefix}"
  auto_accept_shared_attachments  = "disable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"
  amazon_side_asn                 = var.transit_gateway_asn
  tags                            = merge(var.tags, { Name = "${var.name_prefix}-tgw" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  subnet_ids         = aws_subnet.transit[*].id
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = aws_vpc.hub.id

  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-tgw-hub-attach" })
}

# Route spoke traffic via TGW through private route tables
resource "aws_route" "private_tgw" {
  count                  = var.az_count
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = var.spoke_supernet_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.hub]
}

# Share TGW with the AWS Organization via RAM
resource "aws_ram_resource_share" "tgw" {
  name                      = "${var.name_prefix}-tgw-share"
  allow_external_principals = false
  tags                      = merge(var.tags, { Name = "${var.name_prefix}-tgw-share" })
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "org" {
  principal          = var.organization_arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

# VPC Flow Logs
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.name_prefix}"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = aws_kms_key.flow_logs.arn
  tags              = var.tags
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.name_prefix}-flow-logs-role"
  tags = var.tags

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
  name = "${var.name_prefix}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream",
          "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*"]
        Resource = aws_kms_key.flow_logs.arn
      }
    ]
  })
}

resource "aws_flow_log" "hub" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.hub.id
  tags            = merge(var.tags, { Name = "${var.name_prefix}-hub-flow-log" })
}

# Security Group for VPC Interface Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name_prefix}-vpc-endpoints-sg"
  description = "Allow HTTPS from VPC to interface endpoints"
  vpc_id      = aws_vpc.hub.id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-vpc-endpoints-sg" })

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.hub_vpc_cidr]
    description = "HTTPS from VPC CIDR"
  }
}

# Gateway Endpoints (no cost)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.hub.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(aws_route_table.private[*].id, [aws_route_table.public.id])
  tags              = merge(var.tags, { Name = "${var.name_prefix}-s3-endpoint" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.hub.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
  tags              = merge(var.tags, { Name = "${var.name_prefix}-dynamodb-endpoint" })
}

# Interface Endpoints for SSM (enables Session Manager without internet)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.hub.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags                = merge(var.tags, { Name = "${var.name_prefix}-ssm-endpoint" })
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.hub.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags                = merge(var.tags, { Name = "${var.name_prefix}-ssmmessages-endpoint" })
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.hub.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  tags                = merge(var.tags, { Name = "${var.name_prefix}-ec2messages-endpoint" })
}
