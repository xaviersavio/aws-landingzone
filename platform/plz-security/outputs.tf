output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = module.security.guardduty_detector_id
}

output "cloudtrail_arn" {
  description = "Organization CloudTrail ARN"
  value       = module.security.cloudtrail_arn
}

output "access_analyzer_arn" {
  description = "IAM Access Analyzer ARN"
  value       = module.security.access_analyzer_arn
}
