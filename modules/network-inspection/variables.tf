variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "vpc_id" {
  description = "ID of the hub VPC to deploy the inspection layer into"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones (must match hub VPC AZ count)"
  type        = number
  default     = 2
}

variable "inspection_subnet_base_cidr" {
  description = "Base CIDR for inspection subnets — must not overlap existing hub subnets"
  type        = string
  default     = "10.0.6.0/24"
}

variable "nat_gateway_ids" {
  description = "List of NAT Gateway IDs (one per AZ, same order as AZs)"
  type        = list(string)
}

variable "transit_route_table_ids" {
  description = "List of transit subnet route table IDs to update (one per AZ)"
  type        = list(string)
}

variable "public_route_table_id" {
  description = "Public subnet route table ID for return traffic routing fix"
  type        = string
}

variable "spoke_supernet_cidr" {
  description = "Supernet CIDR covering all spoke VPCs (for return routing)"
  type        = string
  default     = "10.0.0.0/8"
}

variable "log_archive_bucket" {
  description = "S3 bucket name in log archive account for firewall logs"
  type        = string
}

variable "blocked_domains" {
  description = "List of domains to block via firewall DENYLIST rule"
  type        = list(string)
  default = [
    # Common malware / C2 domains — extend for your environment
    "*.ru",
    "*.onion",
  ]
}

variable "allowed_domains" {
  description = "Additional domains to allow beyond default AWS service domains"
  type        = list(string)
  default     = []
}

variable "default_action" {
  description = "Default action for unmatched traffic: 'drop' (strict) or 'alert' (permissive)"
  type        = string
  default     = "drop"
  validation {
    condition     = contains(["drop", "alert"], var.default_action)
    error_message = "default_action must be 'drop' or 'alert'"
  }
}

variable "enable_deletion_protection" {
  description = "Enable deletion/change protection on the firewall (set false only for tear-down)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
