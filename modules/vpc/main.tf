resource "aws_vpc" "vray_vpc" {
  cidr_block = var.subnet_area_cidr

  tags = {
    Name = "vray_vpc"
  }
}

resource "aws_subnet" "vray_public_subnet" {
  vpc_id     = aws_vpc.vray_vpc.id
  count      = 2
  cidr_block = cidrsubnet(var.subnet_area_cidr, 8, 2 * (count.index))

  tags = {
    Name = "vRay Public${count.index} <-> Internet Gateway"
  }
}

resource "aws_subnet" "vray_privated_subnet" {
  vpc_id     = aws_vpc.vray_vpc.id
  count      = 2
  cidr_block = cidrsubnet(var.subnet_area_cidr, 8, 2 * (count.index + 1) - 1)

  tags = {
    Name = "vRay Privated${count.index} -> NAT Gateway${count.index}"
  }
}

resource "aws_eip" "vray_eip_4_natgw" {
  count = 2
  vpc   = true
}

resource "aws_nat_gateway" "vray_vpc_natgw" {
  count         = 2
  allocation_id = aws_eip.vray_eip_4_natgw[count.index].id
  subnet_id     = aws_subnet.vray_public_subnet[count.index].id

  tags = {
    Name = "NATGW (on Public subnet)"
  }
}

resource "aws_internet_gateway" "vray_vpc_igw" {
  vpc_id = aws_vpc.vray_vpc.id

  tags = {
    Name = "Internet Gateway"
  }
}

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

resource "aws_route_table_association" "vray_vpc_us_east2a_public_association" {
  count          = 2
  subnet_id      = aws_subnet.vray_public_subnet[count.index].id
  route_table_id = aws_route_table.vray_vpc_us_east2a_public.id
}

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

resource "aws_route_table_association" "vray_vpc_us_east2a_privated_association" {
  count          = 2
  subnet_id      = aws_subnet.vray_privated_subnet[count.index].id
  route_table_id = aws_route_table.vray_vpc_us_east2a_privated[count.index].id
}
