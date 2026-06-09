output "tfc_oidc_provider_arn" {
  description = "ARN of the HCP Terraform OIDC provider"
  value       = module.identity.tfc_oidc_provider_arn
}

output "tfc_role_arns" {
  description = "IAM role ARNs for each HCP Terraform workspace"
  value       = module.identity.tfc_role_arns
}

output "permission_set_arns" {
  description = "IAM Identity Center permission set ARNs"
  value       = module.identity.permission_set_arns
}

output "sso_instance_arn" {
  description = "IAM Identity Center instance ARN"
  value       = module.identity.sso_instance_arn
}
