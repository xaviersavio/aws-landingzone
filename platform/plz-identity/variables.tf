variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tfc_organization" {
  description = "HCP Terraform organization name for OIDC trust"
  type        = string
  default     = ""
}

variable "tfc_workspaces" {
  description = "HCP Terraform workspaces to create OIDC IAM roles for"
  type = map(object({
    project    = string
    workspace  = string
    policy_arn = string
  }))
  default = {}
}

variable "trusted_account_arns" {
  description = "ARNs allowed to assume cross-account roles"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
