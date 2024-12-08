terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "dev.kpena.tfstate"
    key    = "cloud-init-data/terraform.tfstate"
    region = "us-east-1"
  }
}


provider "aws" {
  region = "ap-northeast-1"
}

