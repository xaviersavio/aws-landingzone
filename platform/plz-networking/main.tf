module "networking" {
  source = "../../modules/networking"

  name_prefix             = var.name_prefix
  aws_region              = var.aws_region
  hub_vpc_cidr            = var.hub_vpc_cidr
  spoke_supernet_cidr     = var.spoke_supernet_cidr
  az_count                = var.az_count
  transit_gateway_asn     = var.transit_gateway_asn
  organization_arn        = var.organization_arn
  flow_log_retention_days = var.flow_log_retention_days

  tags = merge(var.tags, {
    Environment = "management"
    Layer       = "platform"
  })
}
