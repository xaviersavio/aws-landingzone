terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_organizations_organization" "this" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "account.amazonaws.com",
    "ram.amazonaws.com",
    "controltower.amazonaws.com",
  ]

  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]
}

# Organizational Units
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "workloads_dev" {
  name      = "Dev"
  parent_id = aws_organizations_organizational_unit.workloads.id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "workloads_test" {
  name      = "Test"
  parent_id = aws_organizations_organizational_unit.workloads.id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "workloads_prod" {
  name      = "Prod"
  parent_id = aws_organizations_organizational_unit.workloads.id
  tags      = var.tags
}

# Service Control Policies
resource "aws_organizations_policy" "deny_root_usage" {
  name        = "DenyRootUserUsage"
  description = "Deny usage of root user credentials across all accounts"
  type        = "SERVICE_CONTROL_POLICY"
  tags        = var.tags

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyRootUser"
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
      Condition = {
        StringLike = {
          "aws:PrincipalArn" = "arn:aws:iam::*:root"
        }
      }
    }]
  })
}

resource "aws_organizations_policy" "restrict_regions" {
  name        = "RestrictRegions"
  description = "Restrict AWS actions to approved regions"
  type        = "SERVICE_CONTROL_POLICY"
  tags        = var.tags

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyUnsupportedRegions"
      Effect = "Deny"
      NotAction = [
        "a4b:*", "acm:*", "aws-marketplace-management:*", "aws-marketplace:*",
        "aws-portal:*", "budgets:*", "ce:*", "chime:*", "cloudfront:*",
        "config:*", "cur:*", "directconnect:*", "ec2:DescribeRegions",
        "ec2:DescribeTransitGateways", "globalaccelerator:*", "health:*",
        "iam:*", "importexport:*", "kms:*", "mobileanalytics:*",
        "networkmanager:*", "organizations:*", "pricing:*", "route53:*",
        "route53domains:*", "s3:GetAccountPublic*", "s3:ListAllMyBuckets",
        "s3:PutAccountPublic*", "shield:*", "sts:*", "support:*",
        "trustedadvisor:*", "waf-regional:*", "waf:*", "wafv2:*",
        "wellarchitected:*"
      ]
      Resource = "*"
      Condition = {
        StringNotEquals = {
          "aws:RequestedRegion" = var.allowed_regions
        }
      }
    }]
  })
}

resource "aws_organizations_policy" "deny_public_s3" {
  name        = "DenyPublicS3"
  description = "Prevent making S3 buckets or objects public"
  type        = "SERVICE_CONTROL_POLICY"
  tags        = var.tags

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicS3ACL"
        Effect = "Deny"
        Action = ["s3:PutObjectAcl"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = ["public-read", "public-read-write", "authenticated-read"]
          }
        }
      },
      {
        Sid    = "DenyDisablePublicAccessBlock"
        Effect = "Deny"
        Action = ["s3:PutBucketPublicAccessBlock"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "s3:PublicAccessBlockConfiguration/BlockPublicAcls"       = "false"
            "s3:PublicAccessBlockConfiguration/BlockPublicPolicy"     = "false"
            "s3:PublicAccessBlockConfiguration/IgnorePublicAcls"      = "false"
            "s3:PublicAccessBlockConfiguration/RestrictPublicBuckets" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy" "require_mfa" {
  name        = "RequireMFAForSensitiveActions"
  description = "Require MFA for sensitive IAM actions"
  type        = "SERVICE_CONTROL_POLICY"
  tags        = var.tags

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DenyWithoutMFA"
      Effect = "Deny"
      Action = [
        "iam:CreateAccessKey",
        "iam:DeleteVirtualMFADevice",
        "iam:DeactivateMFADevice",
        "iam:UpdateAccountPasswordPolicy",
      ]
      Resource = "*"
      Condition = {
        BoolIfExists = {
          "aws:MultiFactorAuthPresent" = "false"
        }
      }
    }]
  })
}

resource "aws_organizations_policy" "deny_leave_org" {
  name        = "DenyLeaveOrganization"
  description = "Prevent accounts from leaving the organization"
  type        = "SERVICE_CONTROL_POLICY"
  tags        = var.tags

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyLeaveOrganization"
      Effect   = "Deny"
      Action   = ["organizations:LeaveOrganization"]
      Resource = "*"
    }]
  })
}

# SCP Attachments to Organization Root
resource "aws_organizations_policy_attachment" "deny_root_root" {
  policy_id = aws_organizations_policy.deny_root_usage.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "restrict_regions_root" {
  policy_id = aws_organizations_policy.restrict_regions.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "deny_public_s3_root" {
  policy_id = aws_organizations_policy.deny_public_s3.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "require_mfa_root" {
  policy_id = aws_organizations_policy.require_mfa.id
  target_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_policy_attachment" "deny_leave_org_root" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organization.this.roots[0].id
}

# Platform Accounts
resource "aws_organizations_account" "security" {
  name      = "${var.org_name}-security"
  email     = var.account_emails["security"]
  parent_id = aws_organizations_organizational_unit.security.id
  tags      = merge(var.tags, { Name = "${var.org_name}-security" })

  lifecycle {
    ignore_changes = [email, name]
  }
}

resource "aws_organizations_account" "log_archive" {
  name      = "${var.org_name}-log-archive"
  email     = var.account_emails["log_archive"]
  parent_id = aws_organizations_organizational_unit.security.id
  tags      = merge(var.tags, { Name = "${var.org_name}-log-archive" })

  lifecycle {
    ignore_changes = [email, name]
  }
}

resource "aws_organizations_account" "networking" {
  name      = "${var.org_name}-networking"
  email     = var.account_emails["networking"]
  parent_id = aws_organizations_organizational_unit.infrastructure.id
  tags      = merge(var.tags, { Name = "${var.org_name}-networking" })

  lifecycle {
    ignore_changes = [email, name]
  }
}

resource "aws_organizations_account" "shared_services" {
  name      = "${var.org_name}-shared-services"
  email     = var.account_emails["shared_services"]
  parent_id = aws_organizations_organizational_unit.infrastructure.id
  tags      = merge(var.tags, { Name = "${var.org_name}-shared-services" })

  lifecycle {
    ignore_changes = [email, name]
  }
}
