output "spoke_vpc_id" {
  description = "Spoke VPC ID"
  value       = aws_vpc.spoke.id
}

output "spoke_vpc_cidr" {
  description = "Spoke VPC CIDR"
  value       = aws_vpc.spoke.cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "tgw_attachment_id" {
  description = "Transit Gateway attachment ID"
  value       = aws_ec2_transit_gateway_vpc_attachment.spoke.id
}

output "permission_boundary_arn" {
  description = "ARN of the workload permission boundary policy"
  value       = aws_iam_policy.permission_boundary.arn
}
