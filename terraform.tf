###########################################################
#####                  TF CONFIG                     ######
###########################################################

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
    backend "s3" {
    bucket = "tfstate-184239210367"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

# provider "vault" {
#   address = "http://localhost:8200"
# token was provided through an environment variable $VAULT_TOKEN.
# }

provider "aws" {
  region = "us-east-1"
}

###########################################################
#####                BACKEND CONFIG                  ######
###########################################################

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "s3-remote-state" {
    bucket = "tfstate-${data.aws_caller_identity.current.account_id}"
    tags   = var.common-tags
}

resource "aws_s3_bucket_versioning" "s3-remote-state-versioning" {
  bucket = aws_s3_bucket.s3-remote-state.id
  versioning_configuration {
    status = "Enabled"
  }
}