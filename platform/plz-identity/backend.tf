terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "REPLACE_ME-terraform-state"
    key          = "platform/plz-identity/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

# IAM Identity Center must be managed from the management account
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "management"
      Layer       = "platform"
      Component   = "plz-identity"
    }
  }
}
