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
    key          = "workloads/REPLACE_APP_NAME/REPLACE_ENV/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      ManagedBy   = "Terraform"
      Application = var.app_name
      Environment = var.environment
      Layer       = "workload"
    }
  }
}
