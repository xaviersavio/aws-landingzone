variable "aws_region" {
  description = "Primary AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "org_name" {
  description = "Short name for the organization (used in resource naming)"
  type        = string
}

variable "allowed_regions" {
  description = "AWS regions permitted for use across the organization"
  type        = list(string)
  default     = ["ap-southeast-2", "ap-southeast-1", "us-east-1"]
}

variable "account_emails" {
  description = "Email addresses for each platform account"
  type        = map(string)
  sensitive   = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
