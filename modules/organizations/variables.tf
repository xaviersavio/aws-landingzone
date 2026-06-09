variable "org_name" {
  description = "Short name for the organization used in resource naming"
  type        = string
}

variable "allowed_regions" {
  description = "List of AWS regions permitted for use"
  type        = list(string)
  default     = ["ap-southeast-2", "ap-southeast-1", "us-east-1"]
}

variable "account_emails" {
  description = "Email addresses for each platform AWS account (keys: security, log_archive, networking, shared_services)"
  type        = map(string)
  sensitive   = true
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
