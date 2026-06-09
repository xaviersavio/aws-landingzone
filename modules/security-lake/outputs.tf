output "data_lake_arn" {
  description = "ARN of the Security Lake data lake"
  value       = aws_securitylake_data_lake.primary.arn
}

output "data_lake_s3_bucket_arn" {
  description = "ARN of the S3 bucket backing Security Lake"
  value       = aws_securitylake_data_lake.primary.s3_bucket_arn
}

output "athena_subscriber_id" {
  description = "ID of the internal Athena subscriber"
  value       = aws_securitylake_subscriber.athena.id
}

output "splunk_subscriber_id" {
  description = "ID of the Splunk SIEM subscriber (empty if not configured)"
  value       = length(aws_securitylake_subscriber.splunk) > 0 ? aws_securitylake_subscriber.splunk[0].id : ""
}

output "security_alerts_topic_arn" {
  description = "ARN of the SNS topic for critical security findings"
  value       = aws_sns_topic.security_alerts.arn
}
