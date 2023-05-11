provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = var.stage
      Owner       = var.app_name
      Application = var.app_name
    }
  }
}

# Use data sources allow configuration to be generic for any region
data "aws_region" "current" {}
data "aws_availability_zones" "available" {}