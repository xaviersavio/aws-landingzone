module "logging" {
  source = "../../modules/logging"

  name_prefix        = var.name_prefix
  log_retention_days = var.log_retention_days

  tags = merge(var.tags, {
    Environment = "management"
    Layer       = "platform"
  })
}
