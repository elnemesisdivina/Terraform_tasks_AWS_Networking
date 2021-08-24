terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws"{
    region = "us-east-2"
}
#-----------------Virtual Privated Cloud----------

resource "aws_vpc" "vray_vpc"{
    cidr_block = "10.0.0.0/16"
    tags = {
      Name     = "vray_vpc"
    } 
}   

#----------------"Public" Subnet--------------

resource "aws_subnet" "vray_public_subnet" {
    vpc_id            = aws_vpc.vray_vpc.id
    cidr_block        = "10.0.0.0/24"
    #availability_zone = "us-east-2a"
    tags = {
      Name            = "vRay Public-> Internet Gateway"
    }
}
#---------------"Privated" Subnet--------------

resource "aws_subnet" "vray_privated_subnet"{
  vpc_id            = aws_vpc.vray_vpc.id
  cidr_block        = "10.0.1.0/24"
  #availability_zone = "us-east-2a"
  tags = {
    Name            = "vRay Privated-> NAT Gateway"
    }
}

#----------------Elastic IP---------------

resource "aws_eip" "vray_eip_4_natgw"{
  vpc = true
}
#-----------------NAT Gateway--------------

resource "aws_nat_gateway" "vray_vpc_natgw"{
  allocation_id       = aws_eip.vray_eip_4_natgw.id
  subnet_id           = aws_subnet.vray_public_subnet.id
  tags = {
    Name              = "NATGW (on Public subnet)"
  }
}

#-----check poitn of IP address designated-----
output "nat_gateway_ip" {
  value       = aws_eip.vray_eip_4_natgw.public_ip
  description = "The private IP address of NAT Gateway."
}

#-------------Internet Cloud Gateway------------- 

resource "aws_internet_gateway" "vray_vpc_igw"{
  vpc_id              = aws_vpc.vray_vpc.id

  tags = {
    Name              = "Internet Gateway"
  }
}

#----------Route table Public Subnet ----------------------------

resource "aws_route_table" "vray_vpc_us_east2a_public"{
  vpc_id              = aws_vpc.vray_vpc.id
  route {
    cidr_block        = "0.0.0.0/0"
    gateway_id        = aws_internet_gateway.vray_vpc_igw.id
  }

  tags = {
    Name              = "Public subnet route Table or Default route to Internet from Public Subnet"
  }
}

#------Association Route table and Public subnet-------------

resource "aws_route_table_association" "vray_vpc_us_east2a_public_association" {
  subnet_id          = aws_subnet.vray_public_subnet.id
  route_table_id     = aws_route_table.vray_vpc_us_east2a_public.id
}

#----------Route table Privated Subnet ----------------------------

resource "aws_route_table" "vray_vpc_us_east2a_privated" {
  vpc_id              = aws_vpc.vray_vpc.id
  route {
    cidr_block        = "0.0.0.0/0"
    nat_gateway_id    = aws_nat_gateway.vray_vpc_natgw.id
  }

  tags = {
    Name              = "Privated subnet route Table or Default route to NATGW from Privated Subnet"
  }
}

#--------------Association Route table and Privated subnet-------------

resource "aws_route_table_association" "vray_vpc_us_east2a_privated_association" {
  subnet_id         = aws_subnet.vray_privated_subnet.id  
  route_table_id    = aws_route_table.vray_vpc_us_east2a_privated.id 
}

#-------------------------Secuirty Group--------------------------------

resource "aws_security_group" "vray_security_group"{
  name              = "vray_security_group_SG"
  description       = "Allow SSH inbound connections"
  vpc_id            = aws_vpc.vray_vpc.id
  ingress {
     from_port      = 22
     to_port        = 22
     protocol       = "tcp"
     cidr_blocks    = ["0.0.0.0/0"]
  }
  egress {#just to make sure but AWS will not add anything
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name            = "vRay Security Group allow ssh"
  }
}

#-------------------Creation of the instance in Privated Subnet---------------------------

resource "aws_instance" "vray_instance" {
  ami                         = "ami-00399ec92321828f5"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.vray_key_pair.key_name
  vpc_security_group_ids      = [ aws_security_group.vray_security_group.id ]
  subnet_id                   = aws_subnet.vray_privated_subnet.id
  #associate_public_ip_address = true

  tags = {
    Name                      = "Instance vRay"
  }
}

#-------------------Creation of the JumpBox in Privated Subnet---------------------------
#not possible to reach Privated subnet within the VPN!!!
resource "aws_instance" "vray_jumpbox" {
  ami                         = "ami-00399ec92321828f5"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.vray_key_pair.key_name
  vpc_security_group_ids      = [ aws_security_group.vray_security_group.id ]
  subnet_id                   = aws_subnet.vray_public_subnet.id
  associate_public_ip_address = true

  tags = {
    Name                      = "Jumpbox vRay"
  }
}

#---------Get the public IP of the instance------

output "instance_ip_addr" {
  value        = aws_instance.vray_instance.private_ip
#  value       = "{aws_instance.vray_instance.privated_ip}"
  description  = "The private IP address of the vRay instance."
}

output "jumpbox_ip_addr" {
  value        = aws_instance.vray_jumpbox.public_ip
#  value       = "{aws_instance.vray_instance.public_ip}"
  description  = "The public IP address of the vRay Jumpbox."
}


#--------creation of Privated Key-----------

variable "key_name" {} #to ask creator a name for the keypair to be created so the string enter here will be used for the key!!!

resource "tls_private_key" "vray_pk" {
  algorithm   = "RSA"
  rsa_bits    = 4096
}

#-------Creation of pair keys on AWS and my local machine--------

resource "aws_key_pair" "vray_key_pair" {
  key_name    = var.key_name #create Pair keys on AWS
  public_key  = tls_private_key.vray_pk.public_key_openssh
   
  provisioner "local-exec" { # Create "vrayKey.pem" file with ssh key on my local Machine
    command   = "echo '${tls_private_key.vray_pk.private_key_pem}' > ./'${var.key_name}'.pem"
  }
  provisioner "local-exec" { #lazy as Iam use this to change permissions on file on local MAchine
    command   = "chmod 400 ./'${var.key_name}'.pem"
  }
/*  provisioner "local-exec" {#add permanently to ssh
    command = "ssh-add -K ./'${var.key_name}'.pem"
  }
*/
}

#-------check PK generated fort this instance-------

output "ssh_key" {
  sensitive   = true #can use sensitive_content = to $value to get the key
  description = "ssh key generated on teh fly"
  value       = tls_private_key.vray_pk.private_key_pem
}
