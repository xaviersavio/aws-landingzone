variable "aws_region" {
  description = "AWS region for this deployment"
  type        = string
  default     = "ap-southeast-2"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "security_account_id" {
  description = "AWS account ID of the security account (delegated admin)"
  type        = string
  sensitive   = true
}

variable "log_archive_bucket" {
  description = "S3 bucket name in log-archive account (from plz-log-archive outputs)"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID from plz-log-archive for SNS encryption"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN from plz-log-archive for CloudTrail encryption"
  type        = string
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
