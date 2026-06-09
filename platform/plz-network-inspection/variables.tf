variable "aws_region" {
  description = "AWS region"
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

variable "vpc_id" {
  description = "Hub VPC ID (from plz-networking outputs)"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number
  default     = 2
}

variable "inspection_subnet_base_cidr" {
  description = "Base CIDR for firewall inspection subnets (must not overlap hub subnets)"
  type        = string
  default     = "10.0.6.0/24"
}

variable "nat_gateway_ids" {
  description = "NAT Gateway IDs from plz-networking (one per AZ)"
  type        = list(string)
}

variable "transit_route_table_ids" {
  description = "Transit subnet route table IDs from plz-networking"
  type        = list(string)
}

variable "public_route_table_id" {
  description = "Public subnet route table ID from plz-networking"
  type        = string
}

variable "spoke_supernet_cidr" {
  description = "Supernet CIDR covering all spoke VPCs"
  type        = string
  default     = "10.0.0.0/8"
}

variable "log_archive_bucket" {
  description = "S3 bucket name for firewall FLOW and ALERT logs"
  type        = string
}

variable "blocked_domains" {
  description = "Additional domains to block beyond module defaults"
  type        = list(string)
  default     = []
}

variable "allowed_domains" {
  description = "Additional domains to allow beyond AWS service defaults"
  type        = list(string)
  default     = []
}

variable "default_action" {
  description = "Default firewall action: 'drop' (strict/regulated) or 'alert' (permissive/initial rollout)"
  type        = string
  default     = "alert"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
