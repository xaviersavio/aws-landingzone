output "macie_account_id" {
  description = "Macie account ID in the security account"
  value       = aws_macie2_account.security.id
}

output "log_archive_job_id" {
  description = "ID of the log archive classification job"
  value       = aws_macie2_classification_job.log_archive.id
}

output "findings_filter_arn" {
  description = "ARN of the high-severity findings filter"
  value       = aws_macie2_findings_filter.high_severity.arn
}

output "custom_data_identifier_ids" {
  description = "Map of custom data identifier names to IDs"
  value = {
    nz_ird        = aws_macie2_custom_data_identifier.nz_ird.id
    nz_passport   = aws_macie2_custom_data_identifier.nz_passport.id
    aws_account_id = aws_macie2_custom_data_identifier.aws_account_id.id
  }
}
