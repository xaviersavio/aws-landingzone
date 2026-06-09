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
    key          = "platform/plz-security/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

# Default provider — management account (for delegated admin registration)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "management"
      Layer       = "platform"
      Component   = "plz-security"
    }
  }
}

# Security account provider — GuardDuty detector, SecurityHub account/org config
provider "aws" {
  alias  = "security"
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.security_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Environment = "management"
      Layer       = "platform"
      Component   = "plz-security"
    }
  }
}
