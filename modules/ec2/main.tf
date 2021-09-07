resource "aws_security_group" "vray_security_group_web" {
  name        = "vray_security_group_SG_web"
  description = "Allow SSH, WEB inbound connections"
  vpc_id      = var.vpc_id

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

  egress {
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
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.vray_security_group_web.id]
  subnet_id              = var.subnet_id
  user_data              = file("${path.cwd}/${var.user_data_path}")

  tags = {
    Name = "Instance vRay Web Server"
  }
}