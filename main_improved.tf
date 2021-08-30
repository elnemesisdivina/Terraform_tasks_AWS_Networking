################################
# This one is a DRY approach basic script for task1
#
#################################
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
#-----------------Virtual Privated Cloud----------

variable "subnet_area_cidr" {
  description = "cidr base in case you want different cidr"
  type        = string
  default     = "10.0.0.0/16"
}

resource "aws_vpc" "vray_vpc" {
  cidr_block = var.subnet_area_cidr
  tags = {
    Name = "vray_vpc"
  }
}

resource "aws_subnet" "vray_public_subnet" {
  vpc_id = aws_vpc.vray_vpc.id
  count  = 2
  #cidr_block = locals.subnet_cidrs_public[count.index]
  #availability_zone = "us-east-2a"
  cidr_block = cidrsubnet(var.subnet_area_cidr, 8, 2 * (count.index))
  tags = {
    Name = "vRay Public${count.index} <-> Internet Gateway"
  }
}
resource "aws_subnet" "vray_privated_subnet" {
  vpc_id = aws_vpc.vray_vpc.id
  count  = 2
  #cidr_block = locals.subnet_cidrs_privated[count.index]
  #availability_zone = "us-east-2a"
  cidr_block = cidrsubnet(var.subnet_area_cidr, 8, 2 * (count.index + 1) - 1)
  tags = {
    Name = "vRay Privated${count.index} -> NAT Gateway${count.index}"
  }
}

#----------------Elastic IP---------------

resource "aws_eip" "vray_eip_4_natgw" {
  count = 2
  vpc   = true
}
#-----------------NAT Gateway--------------


resource "aws_nat_gateway" "vray_vpc_natgw" {
  count         = 2
  allocation_id = aws_eip.vray_eip_4_natgw[count.index].id
  subnet_id     = aws_subnet.vray_public_subnet[count.index].id
  tags = {
    Name = "NATGW (on Public subnet)"
  }
}

#-----check poitn of IP address designated-----
output "nat_gateway_ip" {
  value       = aws_eip.vray_eip_4_natgw.*.public_ip
  description = "The private IP address of NAT Gateway."
}

#-------------Internet Cloud Gateway------------- 

resource "aws_internet_gateway" "vray_vpc_igw" {
  vpc_id = aws_vpc.vray_vpc.id

  tags = {
    Name = "Internet Gateway"
  }
}

#----------Route table Public Subnet ----------------------------

resource "aws_route_table" "vray_vpc_us_east2a_public" {
  vpc_id = aws_vpc.vray_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vray_vpc_igw.id
  }

  tags = {
    Name = "Public subnet route Table or Default route to Internet from Public Subnet"
  }
}

#------Association Route table and Public subnet-------------

resource "aws_route_table_association" "vray_vpc_us_east2a_public_association" {
  count          = 2
  subnet_id      = aws_subnet.vray_public_subnet[count.index].id
  route_table_id = aws_route_table.vray_vpc_us_east2a_public.id
}

#----------Route table Privated Subnet ----------------------------

resource "aws_route_table" "vray_vpc_us_east2a_privated" {
  count  = 2
  vpc_id = aws_vpc.vray_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.vray_vpc_natgw[count.index].id
  }

  tags = {
    Name = "Privated${count.index} subnet route Table or Default route to NATGW from Privated Subnet"
  }
}

#--------------Association Route table and Privated subnet-------------

resource "aws_route_table_association" "vray_vpc_us_east2a_privated_association" {
  count          = 2
  subnet_id      = aws_subnet.vray_privated_subnet[count.index].id
  route_table_id = aws_route_table.vray_vpc_us_east2a_privated[count.index].id
}


#-------------------------Secuirty Group--------------------------------

resource "aws_security_group" "vray_security_group" {
  name        = "vray_security_group_SG"
  description = "Allow SSH inbound connections"
  vpc_id      = aws_vpc.vray_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress { #just to make sure but AWS will not add anything
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vRay Security Group allow ssh"
  }
}

###########
#allow ssh adn http
#########
resource "aws_security_group" "vray_security_group_web" {
  name        = "vray_security_group_SG_web"
  description = "Allow SSH, WEB inbound connections"
  vpc_id      = aws_vpc.vray_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress { #just to make sure but AWS will not add anything
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vRay Security Group allow ssh,web"
  }
}


resource "aws_instance" "vray_instance" {
  ami                    = "ami-00399ec92321828f5"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.vray_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.vray_security_group_web.id]
  subnet_id              = aws_subnet.vray_privated_subnet[0].id
  #associate_public_ip_address = true

  tags = {
    Name = "Instance vRay Web Server"
  }
}

#-------------------Creation of the JumpBox in Privated Subnet---------------------------
#not possible to reach Privated subnet within the VPC!!!
resource "aws_instance" "vray_jumpbox" {
  ami                         = "ami-00399ec92321828f5"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.vray_key_pair.key_name
  vpc_security_group_ids      = [aws_security_group.vray_security_group.id]
  subnet_id                   = aws_subnet.vray_public_subnet[0].id
  associate_public_ip_address = true
  tags = {
    Name = "Jumpbox vRay"
  }
}
###########
#ssh to jumbox then CP key and execute the commands to configure web server on instance 
###########

resource "null_resource" "copykey" {

  provisioner "remote-exec" {
    inline = ["echo 'Wait until SSH is ready'"]
  }

  connection {
    type        = "ssh"
    host        = aws_instance.vray_jumpbox.public_ip
    user        = "ubuntu"
    private_key = file("${path.cwd}/${var.key_name}.pem")
    #file("${path.cwd}/${var.key_name}.pem")
    #filename = "${path.cwd}/key.pem"
    # "${file(var.key_path)}"
    /*options 
path.module cpntaining the moduel where the pathg.module epression is place
path.root is the direcoty of root module
path.cwd is the current work directory cdw

*/
  }

  provisioner "file" {
    source      = "${var.key_name}.pem"
    destination = "/tmp/${var.key_name}.pem"
  }
  depends_on = [aws_instance.vray_jumpbox]

  provisioner "remote-exec" {
    inline = [
      "chmod 400 /tmp/${var.key_name}.pem",
      "ssh -i \"/tmp/${var.key_name}.pem\" ubuntu@${aws_instance.vray_instance.private_ip}",
      "apt install update",
      "yum -y install httpd",
      "echo \"<p> My Instance! </p>\" >> /var/www/html/index.html",
      "sudo systemctl enable httpd",
      "sudo systemctl start httpd",
    ]
  }


}


#---------Get the public IP of the instance------

output "instance_ip_addr" {
  value = aws_instance.vray_instance.private_ip
  #  value       = "{aws_instance.vray_instance.privated_ip}"
  description = "The private IP address of the vRay instance."
}

output "jumpbox_ip_addr" {
  value = aws_instance.vray_jumpbox.public_ip
  #  value       = "{aws_instance.vray_instance.public_ip}"
  description = "The public IP address of the vRay Jumpbox."
}


#--------creation of Privated Key-----------

variable "key_name" {} #to ask creator a name for the keypair to be created so the string enter here will be used for the key!!!
#variable "key_path" { default = "/Users/rcastaneda/terraformvray/" }
resource "tls_private_key" "vray_pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#-------Creation of pair keys on AWS and my local machine--------

resource "aws_key_pair" "vray_key_pair" {
  key_name   = var.key_name #create Pair keys on AWS
  public_key = tls_private_key.vray_pk.public_key_openssh

  provisioner "local-exec" { # Create "vrayKey.pem" file with ssh key on my local Machine
    command = "echo '${tls_private_key.vray_pk.private_key_pem}' > ./'${var.key_name}'.pem"
  }
  provisioner "local-exec" { #lazy as Iam use this to change permissions on file on local MAchine
    command = "chmod 400 ./'${var.key_name}'.pem"
  }
  /*  provisioner "local-exec" {#add permanently to ssh
    command = "ssh-add -K ./'${var.key_name}'.pem"
  }
*/
}

#-------check PK generated fort this instance-------

output "ssh_key" {
  sensitive   = true #can use sensitive_content = to $value to get the key
  description = "ssh key generated on The fly"
  value       = tls_private_key.vray_pk.private_key_pem
}
