output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = aws_guardduty_detector.this.id
}

output "config_recorder_id" {
  description = "ID of the AWS Config configuration recorder"
  value       = aws_config_configuration_recorder.this.id
}

output "config_sns_topic_arn" {
  description = "ARN of the SNS topic for Config notifications"
  value       = aws_sns_topic.config.arn
}

output "cloudtrail_arn" {
  description = "ARN of the organization CloudTrail"
  value       = aws_cloudtrail.org.arn
}

output "access_analyzer_arn" {
  description = "ARN of the IAM Access Analyzer"
  value       = aws_accessanalyzer_analyzer.org.arn
}
