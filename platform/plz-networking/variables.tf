variable "aws_region" {
  description = "AWS region for this deployment"
  type        = string
  default     = "ap-southeast-2"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "networking_account_id" {
  description = "AWS account ID of the networking account"
  type        = string
  sensitive   = true
}

variable "organization_arn" {
  description = "ARN of the AWS Organization (from plz-root outputs)"
  type        = string
}

variable "hub_vpc_cidr" {
  description = "CIDR block for the hub VPC"
  type        = string
  default     = "10.0.0.0/20"
}

variable "spoke_supernet_cidr" {
  description = "Supernet CIDR covering all spoke VPCs"
  type        = string
  default     = "10.0.0.0/8"
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number
  default     = 2
}

variable "transit_gateway_asn" {
  description = "Private BGP ASN for the Transit Gateway"
  type        = number
  default     = 64512
}

variable "flow_log_retention_days" {
  description = "VPC Flow Log retention in days"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}
