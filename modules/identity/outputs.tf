output "tfc_oidc_provider_arn" {
  description = "ARN of the HCP Terraform OIDC provider"
  value       = aws_iam_openid_connect_provider.tfc.arn
}

output "tfc_role_arns" {
  description = "Map of workspace names to TFC IAM role ARNs"
  value       = { for k, v in aws_iam_role.tfc_role : k => v.arn }
}

output "cross_account_admin_role_arn" {
  description = "ARN of the cross-account administrator role"
  value       = aws_iam_role.cross_account_admin.arn
}

output "cross_account_readonly_role_arn" {
  description = "ARN of the cross-account read-only role"
  value       = aws_iam_role.cross_account_readonly.arn
}

output "sso_instance_arn" {
  description = "ARN of the IAM Identity Center instance"
  value       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
}

output "permission_set_arns" {
  description = "Map of permission set names to ARNs"
  value = {
    admin         = aws_ssoadmin_permission_set.admin.arn
    readonly      = aws_ssoadmin_permission_set.readonly.arn
    network_admin = aws_ssoadmin_permission_set.network_admin.arn
    security_audit = aws_ssoadmin_permission_set.security_audit.arn
    billing       = aws_ssoadmin_permission_set.billing.arn
  }
}
