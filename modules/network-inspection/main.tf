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

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────
# Inspection subnets — dedicated /28 per AZ for firewall endpoints
# Added to the existing hub VPC
# ─────────────────────────────────────────────

resource "aws_subnet" "inspection" {
  count             = var.az_count
  vpc_id            = var.vpc_id
  cidr_block        = cidrsubnet(var.inspection_subnet_base_cidr, 4, count.index)
  availability_zone = local.azs[count.index]
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-inspection-${local.azs[count.index]}"
    Tier = "inspection"
  })
}

resource "aws_route_table" "inspection" {
  count  = var.az_count
  vpc_id = var.vpc_id
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-inspection-rt-${local.azs[count.index]}"
  })
}

# Inspection subnets route to NAT GW for post-inspection egress
resource "aws_route" "inspection_to_nat" {
  count                  = var.az_count
  route_table_id         = aws_route_table.inspection[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_ids[count.index]
}

resource "aws_route_table_association" "inspection" {
  count          = var.az_count
  subnet_id      = aws_subnet.inspection[count.index].id
  route_table_id = aws_route_table.inspection[count.index].id
}

# ─────────────────────────────────────────────
# Firewall Rule Groups
# ─────────────────────────────────────────────

# Stateless: drop fragmented packets and ICMP echo to internet
resource "aws_networkfirewall_rule_group" "stateless_drops" {
  capacity = 100
  name     = "${var.name_prefix}-stateless-drops"
  type     = "STATELESS"
  tags     = var.tags

  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {
        stateless_rule {
          priority = 10
          rule_definition {
            actions = ["aws:drop"]
            match_attributes {
              protocols = [1] # ICMP
              destination {
                address_definition = "0.0.0.0/0"
              }
            }
          }
        }
      }
    }
  }
}

# Stateful: block known malicious and unwanted domains
resource "aws_networkfirewall_rule_group" "block_domains" {
  capacity = 1000
  name     = "${var.name_prefix}-block-domains"
  type     = "STATEFUL"
  tags     = var.tags

  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = var.blocked_domains
      }
    }
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }
}

# Stateful: allow AWS service endpoints explicitly
resource "aws_networkfirewall_rule_group" "allow_aws" {
  capacity = 500
  name     = "${var.name_prefix}-allow-aws-services"
  type     = "STATEFUL"
  tags     = var.tags

  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets = concat([
          ".amazonaws.com",
          ".cloudfront.net",
          ".awsstatic.com",
          ".amazon.com",
        ], var.allowed_domains)
      }
    }
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }
}

# Stateful: custom Suricata rules for threat detection
resource "aws_networkfirewall_rule_group" "threat_detection" {
  capacity = 500
  name     = "${var.name_prefix}-threat-detection"
  type     = "STATEFUL"
  tags     = var.tags

  rule_group {
    rules_source {
      rules_string = <<-RULES
        # Block crypto mining pools
        reject tcp any any -> any 3333 (msg:"Crypto mining pool port 3333"; sid:1000001; rev:1;)
        reject tcp any any -> any 4444 (msg:"Crypto mining pool port 4444"; sid:1000002; rev:1;)
        reject tcp any any -> any 8333 (msg:"Bitcoin port"; sid:1000003; rev:1;)
        # Block common C2 ports
        reject tcp any any -> any 1080 (msg:"SOCKS proxy port"; sid:1000004; rev:1;)
        reject tcp any any -> any 6667 (msg:"IRC C2 channel"; sid:1000005; rev:1;)
        # Alert on large data exfiltration attempts
        alert tcp any any -> any 443 (msg:"Large outbound HTTPS transfer"; dsize:>10000000; sid:1000006; rev:1;)
      RULES
    }
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }
}

# ─────────────────────────────────────────────
# Firewall Policy
# ─────────────────────────────────────────────

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.name_prefix}-firewall-policy"
  tags = var.tags

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:drop"]

    stateless_rule_group_reference {
      priority     = 10
      resource_arn = aws_networkfirewall_rule_group.stateless_drops.arn
    }

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    # Priority 100 — block threats first
    stateful_rule_group_reference {
      priority     = 100
      resource_arn = aws_networkfirewall_rule_group.block_domains.arn
    }

    # Priority 200 — then allow known-good domains
    stateful_rule_group_reference {
      priority     = 200
      resource_arn = aws_networkfirewall_rule_group.allow_aws.arn
    }

    # Priority 300 — threat signatures
    stateful_rule_group_reference {
      priority     = 300
      resource_arn = aws_networkfirewall_rule_group.threat_detection.arn
    }

    # Default stateful action after rules: drop all unmatched (strict posture)
    stateful_default_actions = [var.default_action == "drop" ? "aws:drop_strict" : "aws:alert_strict"]
  }
}

# ─────────────────────────────────────────────
# Network Firewall — one endpoint per AZ
# ─────────────────────────────────────────────

resource "aws_networkfirewall_firewall" "this" {
  name                = "${var.name_prefix}-network-firewall"
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = var.vpc_id
  tags                = var.tags

  delete_protection                 = var.enable_deletion_protection
  firewall_policy_change_protection = var.enable_deletion_protection
  subnet_change_protection          = var.enable_deletion_protection

  dynamic "subnet_mapping" {
    for_each = aws_subnet.inspection
    content {
      subnet_id       = subnet_mapping.value.id
      ip_address_type = "IPV4"
    }
  }
}

# ─────────────────────────────────────────────
# Firewall Logging → Log Archive S3
# ─────────────────────────────────────────────

resource "aws_networkfirewall_logging_configuration" "this" {
  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_type             = "FLOW"
      log_destination_type = "S3"
      log_destination = {
        bucketName = var.log_archive_bucket
        prefix     = "network-firewall/flow"
      }
    }

    log_destination_config {
      log_type             = "ALERT"
      log_destination_type = "S3"
      log_destination = {
        bucketName = var.log_archive_bucket
        prefix     = "network-firewall/alert"
      }
    }
  }
}

# ─────────────────────────────────────────────
# Route table updates — redirect TGW-bound traffic through firewall
# These update the transit subnet route tables in the hub VPC
# One firewall endpoint per AZ (critical — never route cross-AZ)
# ─────────────────────────────────────────────

locals {
  # Map of AZ name → firewall endpoint ID from the firewall sync states
  firewall_endpoint_ids = {
    for sync_state in tolist(aws_networkfirewall_firewall.this.firewall_status[0].sync_states) :
    sync_state.availability_zone => sync_state.attachment[0].endpoint_id
  }
}

# Update transit subnet route tables: 0.0.0.0/0 → firewall endpoint in same AZ
resource "aws_route" "transit_to_firewall" {
  count                  = var.az_count
  route_table_id         = var.transit_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = local.firewall_endpoint_ids[local.azs[count.index]]

  depends_on = [aws_networkfirewall_firewall.this]
}

# Update NAT subnet return route: RFC1918 → firewall (fixes asymmetric routing)
resource "aws_route" "nat_return_to_firewall" {
  count                  = var.az_count
  route_table_id         = var.public_route_table_id
  destination_cidr_block = var.spoke_supernet_cidr
  vpc_endpoint_id        = local.firewall_endpoint_ids[local.azs[count.index]]

  depends_on = [aws_networkfirewall_firewall.this]
}
