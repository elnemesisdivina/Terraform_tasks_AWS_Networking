terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

module "vpc" {
  source = "./modules/vpc"

  subnet_area_cidr = "10.0.0.0/16"
}
