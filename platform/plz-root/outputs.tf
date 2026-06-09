output "organization_id" {
  description = "AWS Organization ID"
  value       = module.organizations.organization_id
}

output "organization_arn" {
  description = "AWS Organization ARN"
  value       = module.organizations.organization_arn
}

output "root_id" {
  description = "Organization root ID"
  value       = module.organizations.root_id
}

output "ou_ids" {
  description = "Organizational Unit IDs"
  value       = module.organizations.ou_ids
}

output "account_ids" {
  description = "Platform AWS account IDs"
  value       = module.organizations.account_ids
  sensitive   = true
}
