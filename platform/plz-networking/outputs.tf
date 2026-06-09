output "hub_vpc_id" {
  description = "Hub VPC ID"
  value       = module.networking.hub_vpc_id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID — share this with spoke accounts"
  value       = module.networking.transit_gateway_id
}

output "transit_gateway_arn" {
  description = "Transit Gateway ARN"
  value       = module.networking.transit_gateway_arn
}

output "transit_gateway_route_table_id" {
  description = "Default TGW route table ID"
  value       = module.networking.transit_gateway_route_table_id
}

output "private_subnet_ids" {
  description = "Hub private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "nat_gateway_public_ips" {
  description = "Egress public IPs (NAT Gateways) — add these to allowlists"
  value       = module.networking.nat_gateway_public_ips
}
