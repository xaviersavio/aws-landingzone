output "hub_vpc_id" {
  description = "ID of the hub VPC"
  value       = aws_vpc.hub.id
}

output "hub_vpc_cidr" {
  description = "CIDR block of the hub VPC"
  value       = aws_vpc.hub.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "transit_subnet_ids" {
  description = "IDs of the transit subnets"
  value       = aws_subnet.transit[*].id
}

output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.arn
}

output "transit_gateway_route_table_id" {
  description = "Default route table ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.association_default_route_table_id
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

output "flow_logs_log_group_arn" {
  description = "ARN of the VPC Flow Logs CloudWatch log group"
  value       = aws_cloudwatch_log_group.flow_logs.arn
}
