variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region for Security Lake deployment"
  type        = string
}

variable "member_account_ids" {
  description = "List of AWS account IDs to collect logs from (all org accounts)"
  type        = list(string)
}

variable "retention_days" {
  description = "Total days to retain Security Lake data before expiration"
  type        = number
  default     = 2555  # 7 years
}

variable "kms_key_id" {
  description = "KMS key ID for SNS topic encryption"
  type        = string
}

variable "splunk_account_id" {
  description = "Splunk SIEM AWS account ID for subscriber (leave empty to skip)"
  type        = string
  default     = ""
}

variable "splunk_external_id" {
  description = "External ID for Splunk subscriber trust relationship"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alert_email" {
  description = "Email address for critical security findings notifications (leave empty to skip)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
