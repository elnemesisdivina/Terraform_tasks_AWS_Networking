

#--------creation of Privated Key-----------
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
}



#-------------------Creation of the Instance Web Server in Privated Subnet---------------------------
#
resource "aws_instance" "vray_instance" {
  ami                    = "ami-00399ec92321828f5"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.vray_key_pair.key_name
  vpc_security_group_ids = [var.aws_sg_instance]
  subnet_id              = var.private_subnet
  user_data              = file("${path.cwd}/../modules/scripts/install_el_apache.sh")

  tags = {
    Name = "Instance vRay Web Server"
  }
  depends_on = [var.exescript_depends_on_private]


}

#-------------------Creation of the JumpBox in Public Subnet---------------------------
#not possible to reach Privated subnet within the VPC!!!
resource "aws_instance" "vray_jumpbox" {
  ami                         = "ami-00399ec92321828f5"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.vray_key_pair.key_name
  vpc_security_group_ids      = [var.aws_sg_jumbox]
  subnet_id                   = var.public_subnet
  associate_public_ip_address = true
  tags = {
    Name = "Jumpbox vRay"
  }
  #depends_on = [var.exescript_depends_on_public]


}




