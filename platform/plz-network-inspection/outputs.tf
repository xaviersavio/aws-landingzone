output "firewall_arn" {
  description = "ARN of the Network Firewall"
  value       = module.network_inspection.firewall_arn
}

output "firewall_endpoint_ids" {
  description = "Map of AZ to firewall endpoint ID"
  value       = module.network_inspection.firewall_endpoint_ids
}

output "inspection_subnet_ids" {
  description = "Inspection subnet IDs"
  value       = module.network_inspection.inspection_subnet_ids
}
