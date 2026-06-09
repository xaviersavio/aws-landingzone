output "firewall_arn" {
  description = "ARN of the AWS Network Firewall"
  value       = aws_networkfirewall_firewall.this.arn
}

output "firewall_id" {
  description = "ID of the AWS Network Firewall"
  value       = aws_networkfirewall_firewall.this.id
}

output "firewall_endpoint_ids" {
  description = "Map of AZ name to firewall endpoint ID (for route tables)"
  value       = local.firewall_endpoint_ids
}

output "inspection_subnet_ids" {
  description = "IDs of the inspection subnets created for firewall endpoints"
  value       = aws_subnet.inspection[*].id
}

output "firewall_policy_arn" {
  description = "ARN of the firewall policy"
  value       = aws_networkfirewall_firewall_policy.this.arn
}
