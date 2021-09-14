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
  source = "../modules/vpc"

}

module "instances" {
  source                       = "../modules/ec2"
  key_name                     = var.key_name
  aws_sg_instance              = module.vpc.aws_sg_instance
  aws_sg_jumbox                = module.vpc.aws_sg_jumbox
  public_subnet                = module.vpc.public_subnet[0]
  private_subnet               = module.vpc.private_subnet[0]
  exescript_depends_on_private = module.vpc.exescript_depends_on_private
  #exescript_depends_on_public  = module.vpc.exescript_depends_on_public

}


output "instance_ip" {
  value = module.instances.instance_ip_addr

  description = "The private IP address of the vRay instance."
}

output "jumpbox_ip" {
  value = module.instances.jumpbox_ip_addr

  description = "The public IP address of the vRay Jumpbox."
}