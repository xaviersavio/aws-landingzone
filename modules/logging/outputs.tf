output "log_archive_bucket_name" {
  description = "Name of the centralized log archive S3 bucket"
  value       = aws_s3_bucket.log_archive.bucket
}

output "log_archive_bucket_arn" {
  description = "ARN of the centralized log archive S3 bucket"
  value       = aws_s3_bucket.log_archive.arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for log archive encryption"
  value       = aws_kms_key.log_archive.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for log archive encryption"
  value       = aws_kms_key.log_archive.arn
}
