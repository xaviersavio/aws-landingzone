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
# IAM — Security Lake service role
# ─────────────────────────────────────────────

resource "aws_iam_role" "security_lake" {
  name = "${var.name_prefix}-security-lake-role"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "securitylake.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          "aws:SourceArn"     = "arn:aws:securitylake:${var.aws_region}:${data.aws_caller_identity.current.account_id}:data-lake/default"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "security_lake" {
  role       = aws_iam_role.security_lake.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSecurityLakeAdministrator"
}

# ─────────────────────────────────────────────
# Security Lake — data lake in primary region
# ─────────────────────────────────────────────

resource "aws_securitylake_data_lake" "primary" {
  meta_store_manager_role_arn = aws_iam_role.security_lake.arn

  configuration {
    region = var.aws_region

    lifecycle_configuration {
      expiration {
        days = var.retention_days
      }

      transition {
        days          = 60
        storage_class = "ONEZONE_IA"
      }

      transition {
        days          = 365
        storage_class = "GLACIER"
      }
    }
  }

  tags       = var.tags
  depends_on = [aws_iam_role_policy_attachment.security_lake]
}

# ─────────────────────────────────────────────
# AWS Log Sources — enabled for all member accounts
# ─────────────────────────────────────────────

resource "aws_securitylake_aws_log_source" "cloudtrail_mgmt" {
  source {
    accounts       = var.member_account_ids
    regions        = [var.aws_region]
    source_name    = "CLOUD_TRAIL_MGMT"
    source_version = "2"
  }
  depends_on = [aws_securitylake_data_lake.primary]
}

resource "aws_securitylake_aws_log_source" "cloudtrail_s3" {
  source {
    accounts       = var.member_account_ids
    regions        = [var.aws_region]
    source_name    = "CLOUD_TRAIL_S3"
    source_version = "1"
  }
  depends_on = [aws_securitylake_data_lake.primary]
}

resource "aws_securitylake_aws_log_source" "vpc_flow" {
  source {
    accounts       = var.member_account_ids
    regions        = [var.aws_region]
    source_name    = "VPC_FLOW"
    source_version = "1"
  }
  depends_on = [aws_securitylake_data_lake.primary]
}

resource "aws_securitylake_aws_log_source" "security_hub" {
  source {
    accounts       = var.member_account_ids
    regions        = [var.aws_region]
    source_name    = "SH_FINDINGS"
    source_version = "1"
  }
  depends_on = [aws_securitylake_data_lake.primary]
}

resource "aws_securitylake_aws_log_source" "route53" {
  source {
    accounts       = var.member_account_ids
    regions        = [var.aws_region]
    source_name    = "ROUTE53"
    source_version = "1"
  }
  depends_on = [aws_securitylake_data_lake.primary]
}

resource "aws_securitylake_aws_log_source" "lambda" {
  source {
    accounts       = var.member_account_ids
    regions        = [var.aws_region]
    source_name    = "LAMBDA_EXECUTION"
    source_version = "1"
  }
  depends_on = [aws_securitylake_data_lake.primary]
}

# ─────────────────────────────────────────────
# Subscribers — SIEM integration
# ─────────────────────────────────────────────

# Splunk subscriber (S3 pull via SQS notifications)
resource "aws_securitylake_subscriber" "splunk" {
  count = var.splunk_account_id != "" ? 1 : 0

  subscriber_name        = "${var.name_prefix}-splunk"
  subscriber_description = "Splunk SIEM integration via S3 access"
  access_types           = ["S3"]

  sources {
    aws_log_source_resource {
      source_name    = "CLOUD_TRAIL_MGMT"
      source_version = "2"
    }
  }
  sources {
    aws_log_source_resource {
      source_name    = "SH_FINDINGS"
      source_version = "1"
    }
  }
  sources {
    aws_log_source_resource {
      source_name    = "VPC_FLOW"
      source_version = "1"
    }
  }

  subscriber_identity {
    external_id = var.splunk_external_id
    principal   = var.splunk_account_id
  }

  tags       = var.tags
  depends_on = [aws_securitylake_data_lake.primary]
}

# ─────────────────────────────────────────────
# IAM role for internal Athena queries against Security Lake
# LAKEFORMATION subscriber principal MUST be an IAM role ARN — not an account ID
# ─────────────────────────────────────────────

resource "aws_iam_role" "security_lake_query" {
  name = "${var.name_prefix}-security-lake-query"
  tags = var.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "security_lake_query" {
  name = "${var.name_prefix}-security-lake-query"
  role = aws_iam_role.security_lake_query.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecurityLakeS3Read"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [
          aws_securitylake_data_lake.primary.s3_bucket_arn,
          "${aws_securitylake_data_lake.primary.s3_bucket_arn}/*"
        ]
      },
      {
        Sid    = "GlueCatalogRead"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase", "glue:GetDatabases",
          "glue:GetTable", "glue:GetTables",
          "glue:GetPartition", "glue:GetPartitions",
          "glue:GetTableVersion", "glue:GetTableVersions",
          "glue:BatchGetPartition"
        ]
        Resource = "*"
      },
      {
        Sid    = "LakeFormationAccess"
        Effect = "Allow"
        Action = ["lakeformation:GetDataAccess"]
        Resource = "*"
      },
      {
        Sid    = "AthenaQueryExecution"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution", "athena:StopQueryExecution",
          "athena:GetQueryExecution", "athena:GetQueryResults",
          "athena:GetWorkGroup", "athena:ListQueryExecutions"
        ]
        Resource = "*"
      },
      {
        Sid    = "QueryResultsWrite"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [
          "arn:aws:s3:::${var.athena_results_bucket}",
          "arn:aws:s3:::${var.athena_results_bucket}/security-lake-queries/*"
        ]
      }
    ]
  })
}

# Athena workgroup — dedicated to Security Lake queries with encrypted results
resource "aws_athena_workgroup" "security_lake" {
  name        = "${var.name_prefix}-security-lake"
  description = "Workgroup for querying AWS Security Lake via Athena"
  tags        = var.tags

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.athena_results_bucket}/security-lake-queries/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = var.kms_key_arn
      }
    }
  }
}

# Internal Athena subscriber
resource "aws_securitylake_subscriber" "athena" {
  subscriber_name        = "${var.name_prefix}-athena-queries"
  subscriber_description = "Internal security team Athena access via Lake Formation"
  access_types           = ["LAKEFORMATION"]

  sources {
    aws_log_source_resource {
      source_name    = "CLOUD_TRAIL_MGMT"
      source_version = "2"
    }
  }
  sources {
    aws_log_source_resource {
      source_name    = "VPC_FLOW"
      source_version = "1"
    }
  }
  sources {
    aws_log_source_resource {
      source_name    = "SH_FINDINGS"
      source_version = "1"
    }
  }
  sources {
    aws_log_source_resource {
      source_name    = "ROUTE53"
      source_version = "1"
    }
  }

  subscriber_identity {
    # Must be an IAM role ARN for LAKEFORMATION access — account ID alone is rejected
    principal   = aws_iam_role.security_lake_query.arn
    # Unique per deployment — avoids cross-environment confusion
    external_id = "${var.name_prefix}-athena-${data.aws_caller_identity.current.account_id}"
  }

  tags       = var.tags
  depends_on = [aws_securitylake_data_lake.primary]
}

# ─────────────────────────────────────────────
# EventBridge notification for new findings
# Fires when Security Hub CRITICAL findings land in Security Lake
# ─────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "critical_findings" {
  name        = "${var.name_prefix}-security-lake-critical"
  description = "Notify on CRITICAL Security Hub findings in Security Lake"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
    detail = {
      findings = {
        Severity = {
          Label = ["CRITICAL", "HIGH"]
        }
        RecordState = ["ACTIVE"]
        WorkflowState = ["NEW"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "critical_findings_sns" {
  rule      = aws_cloudwatch_event_rule.critical_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.security_alerts.arn
}

resource "aws_sns_topic" "security_alerts" {
  name              = "${var.name_prefix}-security-lake-alerts"
  kms_master_key_id = var.kms_key_id
  tags              = var.tags
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
