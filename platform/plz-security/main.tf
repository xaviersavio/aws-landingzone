module "security" {
  source = "../../modules/security"

  providers = {
    aws          = aws
    aws.security = aws.security
  }

  name_prefix         = var.name_prefix
  aws_region          = var.aws_region
  security_account_id = var.security_account_id
  log_archive_bucket  = var.log_archive_bucket
  kms_key_id          = var.kms_key_id
  kms_key_arn         = var.kms_key_arn

  tags = merge(var.tags, {
    Environment = "management"
    Layer       = "platform"
  })
}
