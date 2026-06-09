variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region for this deployment"
  type        = string
}

variable "security_account_id" {
  description = "AWS account ID of the dedicated security account (GuardDuty/SecurityHub delegated admin)"
  type        = string
}

variable "log_archive_bucket" {
  description = "S3 bucket name in the log archive account for CloudTrail and Config"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for SNS topic encryption"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for CloudTrail encryption"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
