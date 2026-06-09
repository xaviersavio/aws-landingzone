variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "app_name" {
  description = "Application name (used in resource naming)"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod"
  }
}

variable "workload_account_id" {
  description = "AWS account ID for this workload environment"
  type        = string
  sensitive   = true
}

variable "spoke_vpc_cidr" {
  description = "CIDR block for this workload's spoke VPC"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones"
  type        = number
  default     = 2
}

variable "transit_gateway_id" {
  description = "Transit Gateway ID from plz-networking (for TGW attachment)"
  type        = string
}

variable "owner" {
  description = "Team or person responsible for this workload"
  type        = string
}

variable "cost_center" {
  description = "Cost center code for billing allocation"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
