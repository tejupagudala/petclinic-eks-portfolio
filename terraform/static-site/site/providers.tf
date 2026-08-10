terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider — region for S3 / Route 53
provider "aws" {
  region = var.aws_region
}

# Pinned to us-east-1 — CloudFront ONLY accepts ACM certs from this region
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
