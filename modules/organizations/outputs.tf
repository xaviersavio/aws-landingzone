output "organization_id" {
  description = "The ID of the AWS Organization"
  value       = aws_organizations_organization.this.id
}

output "organization_arn" {
  description = "The ARN of the AWS Organization"
  value       = aws_organizations_organization.this.arn
}

output "root_id" {
  description = "The ID of the organization root"
  value       = aws_organizations_organization.this.roots[0].id
}

output "master_account_id" {
  description = "The AWS account ID of the management account"
  value       = aws_organizations_organization.this.master_account_id
}

output "ou_ids" {
  description = "Map of OU names to IDs"
  value = {
    security       = aws_organizations_organizational_unit.security.id
    infrastructure = aws_organizations_organizational_unit.infrastructure.id
    workloads      = aws_organizations_organizational_unit.workloads.id
    sandbox        = aws_organizations_organizational_unit.sandbox.id
    workloads_dev  = aws_organizations_organizational_unit.workloads_dev.id
    workloads_test = aws_organizations_organizational_unit.workloads_test.id
    workloads_prod = aws_organizations_organizational_unit.workloads_prod.id
  }
}

output "account_ids" {
  description = "Map of platform account names to AWS account IDs"
  value = {
    security        = aws_organizations_account.security.id
    log_archive     = aws_organizations_account.log_archive.id
    networking      = aws_organizations_account.networking.id
    shared_services = aws_organizations_account.shared_services.id
  }
}
