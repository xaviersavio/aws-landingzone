terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.security]
    }
  }
}

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────
# GuardDuty
# Delegated-admin registration runs in management account.
# Detector + org config run in the security (delegated admin) account.
# ─────────────────────────────────────────────

resource "aws_guardduty_organization_admin_account" "this" {
  admin_account_id = var.security_account_id
}

resource "aws_guardduty_detector" "this" {
  provider = aws.security
  enable   = true
  tags     = var.tags
}

resource "aws_guardduty_detector_feature" "s3_data_events" {
  provider    = aws.security
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  provider    = aws.security
  detector_id = aws_guardduty_detector.this.id
  name        = "EKS_AUDIT_LOGS"
  status      = "ENABLED"
}

resource "aws_guardduty_detector_feature" "ebs_malware_protection" {
  provider    = aws.security
  detector_id = aws_guardduty_detector.this.id
  name        = "EBS_MALWARE_PROTECTION"
  status      = "ENABLED"
}

resource "aws_guardduty_organization_configuration" "this" {
  provider                         = aws.security
  auto_enable_organization_members = "ALL"
  detector_id                      = aws_guardduty_detector.this.id
  depends_on                       = [aws_guardduty_organization_admin_account.this]
}

resource "aws_guardduty_organization_configuration_feature" "s3_data_events" {
  provider    = aws.security
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  auto_enable = "ALL"
  depends_on  = [aws_guardduty_organization_configuration.this]
}

resource "aws_guardduty_organization_configuration_feature" "eks_audit_logs" {
  provider    = aws.security
  detector_id = aws_guardduty_detector.this.id
  name        = "EKS_AUDIT_LOGS"
  auto_enable = "ALL"
  depends_on  = [aws_guardduty_organization_configuration.this]
}

resource "aws_guardduty_organization_configuration_feature" "ebs_malware_protection" {
  provider    = aws.security
  detector_id = aws_guardduty_detector.this.id
  name        = "EBS_MALWARE_PROTECTION"
  auto_enable = "ALL"
  depends_on  = [aws_guardduty_organization_configuration.this]
}

# ─────────────────────────────────────────────
# Security Hub
# Delegated-admin registration runs in management account.
# Account enable + org config + standards run in security account.
# ─────────────────────────────────────────────

resource "aws_securityhub_organization_admin_account" "this" {
  admin_account_id = var.security_account_id
}

resource "aws_securityhub_account" "this" {
  provider                 = aws.security
  enable_default_standards = false
  depends_on               = [aws_securityhub_organization_admin_account.this]
}

resource "aws_securityhub_organization_configuration" "this" {
  provider              = aws.security
  auto_enable           = true
  auto_enable_standards = "NONE"
  depends_on            = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "cis_v140" {
  provider      = aws.security
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.this]
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  provider      = aws.security
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.this]
}

# ─────────────────────────────────────────────
# AWS Config
# ─────────────────────────────────────────────

resource "aws_iam_role" "config" {
  name = "${var.name_prefix}-config-role"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_managed" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  name = "${var.name_prefix}-config-s3"
  role = aws_iam_role.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:PutObject", "s3:GetBucketAcl"]
      Resource = [
        "arn:aws:s3:::${var.log_archive_bucket}",
        "arn:aws:s3:::${var.log_archive_bucket}/aws-config/*"
      ]
    }]
  })
}

resource "aws_config_configuration_recorder" "this" {
  name     = "default"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_sns_topic" "config" {
  name              = "${var.name_prefix}-config-notifications"
  kms_master_key_id = var.kms_key_id
  tags              = var.tags
}

resource "aws_config_delivery_channel" "this" {
  name           = "default"
  s3_bucket_name = var.log_archive_bucket
  s3_key_prefix  = "aws-config"
  sns_topic_arn  = aws_sns_topic.config.arn

  snapshot_delivery_properties {
    delivery_frequency = "TwentyFour_Hours"
  }

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

# Config Rules
resource "aws_config_config_rule" "required_tags" {
  name        = "required-tags"
  description = "Checks that required tags are applied to resources"
  depends_on  = [aws_config_configuration_recorder.this]

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    tag1Key = "Environment"
    tag2Key = "Owner"
    tag3Key = "CostCenter"
  })
}

resource "aws_config_config_rule" "encrypted_volumes" {
  name        = "encrypted-volumes"
  description = "Checks that EBS volumes are encrypted"
  depends_on  = [aws_config_configuration_recorder.this]

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }
}

resource "aws_config_config_rule" "s3_encryption" {
  name        = "s3-bucket-server-side-encryption-enabled"
  description = "Checks that S3 buckets have SSE enabled"
  depends_on  = [aws_config_configuration_recorder.this]

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }
}

resource "aws_config_config_rule" "s3_public_access_block" {
  name        = "s3-account-level-public-access-blocks-periodic"
  description = "Checks that S3 account-level public access block is enabled"
  depends_on  = [aws_config_configuration_recorder.this]

  source {
    owner             = "AWS"
    source_identifier = "S3_ACCOUNT_LEVEL_PUBLIC_ACCESS_BLOCKS_PERIODIC"
  }
}

resource "aws_config_config_rule" "root_mfa" {
  name        = "root-account-mfa-enabled"
  description = "Checks that root account has MFA enabled"
  depends_on  = [aws_config_configuration_recorder.this]

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }
}

resource "aws_config_config_rule" "iam_password_policy" {
  name        = "iam-password-policy"
  description = "Checks that IAM password policy meets requirements"
  depends_on  = [aws_config_configuration_recorder.this]

  source {
    owner             = "AWS"
    source_identifier = "IAM_PASSWORD_POLICY"
  }

  input_parameters = jsonencode({
    RequireUppercaseCharacters = "true"
    RequireLowercaseCharacters = "true"
    RequireSymbols             = "true"
    RequireNumbers             = "true"
    MinimumPasswordLength      = "14"
    PasswordReusePrevention    = "24"
    MaxPasswordAge             = "90"
  })
}

resource "aws_config_config_rule" "vpc_flow_logs_enabled" {
  name        = "vpc-flow-logs-enabled"
  description = "Checks that VPC Flow Logs are enabled"
  depends_on  = [aws_config_configuration_recorder.this]

  source {
    owner             = "AWS"
    source_identifier = "VPC_FLOW_LOGS_ENABLED"
  }
}

# ─────────────────────────────────────────────
# CloudTrail (Organization)
# ─────────────────────────────────────────────

resource "aws_cloudtrail" "org" {
  name                          = "${var.name_prefix}-org-trail"
  s3_bucket_name                = var.log_archive_bucket
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  is_organization_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = var.kms_key_arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }

    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-org-trail" })
}

# ─────────────────────────────────────────────
# IAM Access Analyzer (Organization scope)
# ─────────────────────────────────────────────

resource "aws_accessanalyzer_analyzer" "org" {
  analyzer_name = "${var.name_prefix}-org-analyzer"
  type          = "ORGANIZATION"
  tags          = var.tags
}

# ─────────────────────────────────────────────
# IAM Account Password Policy
# ─────────────────────────────────────────────

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
  hard_expiry                    = false
}
