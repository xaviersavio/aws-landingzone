output "log_archive_bucket_name" {
  description = "Name of the centralized log archive bucket"
  value       = module.logging.log_archive_bucket_name
}

output "log_archive_bucket_arn" {
  description = "ARN of the centralized log archive bucket"
  value       = module.logging.log_archive_bucket_arn
}

output "kms_key_id" {
  description = "KMS key ID for log encryption"
  value       = module.logging.kms_key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for log encryption"
  value       = module.logging.kms_key_arn
}
