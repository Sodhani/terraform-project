terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "2.70.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

locals {
  root_domain = "sodhani.xyz"
}

data "aws_s3_bucket" "landingPage" {
  bucket = "${local.root_domain}-root"
}

resource "aws_s3_bucket_object" "htmlFiles" {
  for_each = fileset("htmlFiles/", "*")
  bucket = data.aws_s3_bucket.landingPage.id
  key = each.value
  source = "htmlFiles/${each.value}"
  etag = filemd5("htmlFiles/${each.value}")
}

