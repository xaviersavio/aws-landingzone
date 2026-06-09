variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days before log objects expire in S3"
  type        = number
  default     = 365
}

variable "elb_service_account_id" {
  description = "AWS ELB service account ID for the region (allows ELB access logging)"
  type        = string
  # See: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
  default = "783225319266" # ap-southeast-2
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
