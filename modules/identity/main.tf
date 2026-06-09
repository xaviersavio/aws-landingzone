terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_organizations_organization" "this" {}

# ─────────────────────────────────────────────
# OIDC Provider for Terraform Cloud / HCP Terraform
# Enables dynamic credentials without static AWS keys
# ─────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "tfc" {
  url = "https://app.terraform.io"

  client_id_list = ["aws.workload.identity"]

  thumbprint_list = [
    "9e99a48a9960b14926bb7f3b02e22da2b0ab7280"
  ]

  tags = merge(var.tags, { Name = "terraform-cloud-oidc" })
}

# IAM role assumed by HCP Terraform workspaces via OIDC
resource "aws_iam_role" "tfc_role" {
  for_each = var.tfc_workspaces
  name     = "${var.name_prefix}-tfc-${each.key}"
  tags     = merge(var.tags, { Name = "${var.name_prefix}-tfc-${each.key}" })

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.tfc.arn
      }
      Condition = {
        StringEquals = {
          "app.terraform.io:aud" = "aws.workload.identity"
        }
        StringLike = {
          "app.terraform.io:sub" = "organization:${var.tfc_organization}:project:${each.value.project}:workspace:${each.value.workspace}:run_phase:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "tfc_role" {
  for_each   = var.tfc_workspaces
  role       = aws_iam_role.tfc_role[each.key].name
  policy_arn = each.value.policy_arn
}

# ─────────────────────────────────────────────
# Cross-Account IAM Roles
# Allows the management account to assume roles in member accounts
# ─────────────────────────────────────────────

resource "aws_iam_role" "cross_account_admin" {
  name = "${var.name_prefix}-cross-account-admin"
  tags = merge(var.tags, { Name = "${var.name_prefix}-cross-account-admin" })

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = var.trusted_account_arns }
      Condition = {
        Bool = {
          "aws:MultiFactorAuthPresent" = "true"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cross_account_admin" {
  role       = aws_iam_role.cross_account_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "cross_account_readonly" {
  name = "${var.name_prefix}-cross-account-readonly"
  tags = merge(var.tags, { Name = "${var.name_prefix}-cross-account-readonly" })

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = var.trusted_account_arns }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cross_account_readonly" {
  role       = aws_iam_role.cross_account_readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ─────────────────────────────────────────────
# IAM Identity Center (SSO) Permission Sets
# ─────────────────────────────────────────────

data "aws_ssoadmin_instances" "this" {}

resource "aws_ssoadmin_permission_set" "admin" {
  name             = "AdministratorAccess"
  description      = "Full administrator access"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT4H"
  tags             = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_permission_set" "readonly" {
  name             = "ReadOnlyAccess"
  description      = "Read-only access across all services"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT8H"
  tags             = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_ssoadmin_permission_set" "network_admin" {
  name             = "NetworkAdministrator"
  description      = "Manage VPC, TGW, and networking resources"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT4H"
  tags             = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "network_admin" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.network_admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/job-function/NetworkAdministrator"
}

resource "aws_ssoadmin_permission_set" "security_audit" {
  name             = "SecurityAudit"
  description      = "View security-related resources and configurations"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT8H"
  tags             = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "security_audit" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.security_audit.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_ssoadmin_permission_set" "billing" {
  name             = "BillingAccess"
  description      = "Manage billing and cost management"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT8H"
  tags             = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "billing" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.billing.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/job-function/Billing"
}
