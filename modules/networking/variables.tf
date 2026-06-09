variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "aws_region" {
  description = "AWS region for this deployment"
  type        = string
}

variable "hub_vpc_cidr" {
  description = "CIDR block for the hub VPC"
  type        = string
  default     = "10.0.0.0/20"
}

variable "spoke_supernet_cidr" {
  description = "Supernet CIDR covering all spoke VPCs, routed through TGW"
  type        = string
  default     = "10.0.0.0/8"
}

variable "az_count" {
  description = "Number of availability zones to deploy into"
  type        = number
  default     = 2
}

variable "transit_gateway_asn" {
  description = "Private BGP ASN for the Transit Gateway"
  type        = number
  default     = 64512
}

variable "organization_arn" {
  description = "ARN of the AWS Organization for RAM sharing the TGW"
  type        = string
}

variable "flow_log_retention_days" {
  description = "CloudWatch log retention in days for VPC Flow Logs"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
