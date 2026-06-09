variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "security_account_id" {
  description = "AWS account ID of the security account (Macie delegated admin)"
  type        = string
  sensitive   = true
}

variable "log_archive_account_id" {
  description = "AWS account ID of the log archive account"
  type        = string
  sensitive   = true
}

variable "log_archive_bucket" {
  description = "S3 bucket name of the centralized log archive"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
