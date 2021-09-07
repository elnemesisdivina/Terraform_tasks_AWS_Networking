output "vpc_id" {
    value = aws_vpc.vray_vpc.id
}

output "public_subnet_ids" {
    value = aws_subnet.vray_public_subnet[*].id
}

output "private_subnet_ids" {
    value = aws_subnet.vray_privated_subnet[*].id
}