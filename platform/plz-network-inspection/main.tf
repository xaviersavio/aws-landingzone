module "network_inspection" {
  source = "../../modules/network-inspection"

  name_prefix                 = var.name_prefix
  vpc_id                      = var.vpc_id
  az_count                    = var.az_count
  inspection_subnet_base_cidr = var.inspection_subnet_base_cidr
  nat_gateway_ids             = var.nat_gateway_ids
  transit_route_table_ids     = var.transit_route_table_ids
  public_route_table_id       = var.public_route_table_id
  spoke_supernet_cidr         = var.spoke_supernet_cidr
  log_archive_bucket          = var.log_archive_bucket
  blocked_domains             = var.blocked_domains
  allowed_domains             = var.allowed_domains
  default_action              = var.default_action

  tags = merge(var.tags, {
    Environment = "management"
    Layer       = "platform"
  })
}
