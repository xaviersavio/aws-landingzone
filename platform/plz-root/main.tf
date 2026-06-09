module "organizations" {
  source = "../../modules/organizations"

  org_name        = var.org_name
  allowed_regions = var.allowed_regions
  account_emails  = var.account_emails

  tags = merge(var.tags, {
    Environment = "management"
    Layer       = "platform"
  })
}
