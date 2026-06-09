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

# KMS key for log archive bucket encryption
resource "aws_kms_key" "log_archive" {
  description             = "KMS key for centralized log archive encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-log-archive-key" })

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
        Sid    = "Allow CloudTrail to use the key"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Config to use the key"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "log_archive" {
  name          = "alias/${var.name_prefix}-log-archive"
  target_key_id = aws_kms_key.log_archive.key_id
}

# Centralized log archive S3 bucket
resource "aws_s3_bucket" "log_archive" {
  bucket = "${var.name_prefix}-log-archive-${data.aws_caller_identity.current.account_id}"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-log-archive" })
}

resource "aws_s3_bucket_versioning" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.log_archive.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "log_archive" {
  bucket                  = aws_s3_bucket.log_archive.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id
  policy = data.aws_iam_policy_document.log_archive.json
}

data "aws_iam_policy_document" "log_archive" {
  statement {
    sid    = "DenyNonHTTPS"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.log_archive.arn, "${aws_s3_bucket.log_archive.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.log_archive.arn}/cloudtrail/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid    = "AllowCloudTrailBucketCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.log_archive.arn]
  }

  statement {
    sid    = "AllowConfigWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    actions   = ["s3:PutObject", "s3:GetBucketAcl"]
    resources = [
      "${aws_s3_bucket.log_archive.arn}/aws-config/*",
      aws_s3_bucket.log_archive.arn
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceOrgID"
      values   = [data.aws_organizations_organization.this.id]
    }
  }

  statement {
    sid    = "AllowOrgAccountsELBLogs"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.elb_service_account_id}:root"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.log_archive.arn}/elb-logs/*"]
  }
}

# S3 access logging bucket (logs access to the log archive itself)
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.name_prefix}-access-logs-${data.aws_caller_identity.current.account_id}"
  tags   = merge(var.tags, { Name = "${var.name_prefix}-access-logs" })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_logging" "log_archive" {
  bucket        = aws_s3_bucket.log_archive.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "log-archive-access/"
}
