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

module "jumpbox" {
  source = "./modules/ec2"

  key_name       = "main"
  vpc_id         = module.vpc.vpc_id
  subnet_id      = module.vpc.public_subnet_ids[0]
  user_data_path = "install_el_apache.sh"
}