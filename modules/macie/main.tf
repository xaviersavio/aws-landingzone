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
# Management account — enable Macie + register delegated admin
# ─────────────────────────────────────────────

resource "aws_macie2_account" "management" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

resource "aws_macie2_organization_admin_account" "this" {
  admin_account_id = var.security_account_id
  depends_on       = [aws_macie2_account.management]
}

# ─────────────────────────────────────────────
# Security account — enable Macie + configure org
# All resources below use aws.security provider
# ─────────────────────────────────────────────

resource "aws_macie2_account" "security" {
  provider                     = aws.security
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
  depends_on                   = [aws_macie2_organization_admin_account.this]
}

resource "aws_macie2_organization_configuration" "this" {
  provider    = aws.security
  auto_enable = true
  depends_on  = [aws_macie2_account.security]
}

# ─────────────────────────────────────────────
# Classification jobs
# ─────────────────────────────────────────────

# Weekly scan of the centralized log archive bucket
resource "aws_macie2_classification_job" "log_archive" {
  provider  = aws.security
  job_type  = "SCHEDULED"
  name      = "${var.name_prefix}-log-archive-scan"
  job_status = "RUNNING"

  s3_job_definition {
    bucket_definitions {
      account_id = var.log_archive_account_id
      buckets    = [var.log_archive_bucket]
    }
  }

  schedule_frequency {
    weekly_schedule = "MONDAY"
  }

  tags = var.tags
  depends_on = [aws_macie2_account.security]
}

# On-demand scan triggered for new buckets tagged DataClass=confidential
resource "aws_macie2_classification_job" "confidential_buckets" {
  provider   = aws.security
  job_type   = "ONE_TIME"
  name       = "${var.name_prefix}-confidential-scan"
  job_status = "RUNNING"

  s3_job_definition {
    scoping {
      includes {
        and {
          tag_scope_term {
            comparator = "EQ"
            key        = "TAG"
            tag_values {
              key   = "DataClass"
              value = "confidential"
            }
            target = "S3_OBJECT"
          }
        }
      }
    }

    bucket_criteria {
      includes {
        and {
          tag_criterion {
            comparator = "EQ"
            tag_values {
              key   = "DataClass"
              value = "confidential"
            }
          }
        }
      }
    }
  }

  tags = var.tags
  depends_on = [aws_macie2_account.security]
}

# ─────────────────────────────────────────────
# Findings filters — surface actionable findings
# ─────────────────────────────────────────────

resource "aws_macie2_findings_filter" "high_severity" {
  provider    = aws.security
  name        = "${var.name_prefix}-high-severity"
  description = "Surface HIGH and CRITICAL findings only"
  action      = "NOOP"
  position    = 1

  finding_criteria {
    criterion {
      field = "severity.description"
      eq    = ["High", "Critical"]
    }
  }

  tags = var.tags
  depends_on = [aws_macie2_account.security]
}

# ─────────────────────────────────────────────
# Custom Data Identifiers — org-specific patterns
# ─────────────────────────────────────────────

resource "aws_macie2_custom_data_identifier" "nz_ird" {
  provider    = aws.security
  name        = "NZ-IRD-Number"
  description = "New Zealand Inland Revenue Department tax numbers"
  regex       = "\\b[0-9]{8,9}\\b"
  keywords    = ["IRD", "tax number", "Inland Revenue", "IRD number"]
  maximum_match_distance = 50
  tags = var.tags
  depends_on = [aws_macie2_account.security]
}

resource "aws_macie2_custom_data_identifier" "nz_passport" {
  provider    = aws.security
  name        = "NZ-Passport-Number"
  description = "New Zealand passport numbers"
  regex       = "\\b[A-Z]{2}[0-9]{6}\\b"
  keywords    = ["passport", "NZ passport"]
  maximum_match_distance = 50
  tags = var.tags
  depends_on = [aws_macie2_account.security]
}

resource "aws_macie2_custom_data_identifier" "aws_account_id" {
  provider    = aws.security
  name        = "AWS-Account-ID"
  description = "AWS account IDs that may indicate misplaced account references"
  regex       = "\\b[0-9]{12}\\b"
  keywords    = ["account", "aws account", "account id"]
  maximum_match_distance = 50
  tags = var.tags
  depends_on = [aws_macie2_account.security]
}
