provider "aws" {
  region = var.region

  # fake config for terraform plan check without aws access
  # must be deleted or overwritten in real environment
  # start fake config
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "fake_mock_access_key"
  secret_key                  = "fake_mock_secret_key"
  # enf fake config
}

provider "aws" {
  region = var.region_primary
  alias  = "primary"
  # fake config for terraform plan check without aws access
  # must be deleted or overwritten in real environment
  # start fake config
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "fake_mock_access_key"
  secret_key                  = "fake_mock_secret_key"
  # enf fake config
  default_tags {
    tags = merge(local.default_tags, { "region" = "PRIMARY" })
  }
}

provider "aws" {
  region = var.region_secondary
  alias  = "secondary"
  # fake config for terraform plan check without aws access
  # must be deleted or overwritten in real environment
  # start fake config
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "fake_mock_access_key"
  secret_key                  = "fake_mock_secret_key"
  # enf fake config
  default_tags {
    tags = merge(local.default_tags, { "region" = "SECONDARY" })
  }
}


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.15.0"
    }
  }
}