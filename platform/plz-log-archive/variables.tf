variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "log_archive_account_id" {
  description = "AWS account ID of the log-archive account"
  type        = string
  sensitive   = true
}

variable "log_retention_days" {
  description = "Days to retain log objects in S3 before expiration"
  type        = number
  default     = 365
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
