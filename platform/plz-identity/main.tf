module "identity" {
  source = "../../modules/identity"

  name_prefix          = var.name_prefix
  tfc_organization     = var.tfc_organization
  tfc_workspaces       = var.tfc_workspaces
  trusted_account_arns = var.trusted_account_arns

  tags = merge(var.tags, {
    Environment = "management"
    Layer       = "platform"
  })
}
