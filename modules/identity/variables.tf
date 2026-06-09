variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "tfc_organization" {
  description = "HCP Terraform / Terraform Cloud organization name"
  type        = string
  default     = ""
}

variable "tfc_workspaces" {
  description = "Map of HCP Terraform workspaces to create IAM OIDC roles for"
  type = map(object({
    project    = string
    workspace  = string
    policy_arn = string
  }))
  default = {}
}

variable "trusted_account_arns" {
  description = "List of ARNs allowed to assume cross-account roles (e.g., management account)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
