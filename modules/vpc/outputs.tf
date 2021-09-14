




output "nat_gateway_ip" {
  value       = aws_eip.vray_eip_4_natgw.*.public_ip
  description = "The private IP address of NAT Gateway."
}

output "aws_sg_instance" {
  value = aws_security_group.vray_security_group_web.id

  description = "SG Instance"
}

output "aws_sg_jumbox" {
  value = aws_security_group.vray_security_group.id

  description = "SG JumpBox"

}

output "public_subnet" {
  value = aws_subnet.vray_public_subnet[*].id

  description = "Public Network "

}
output "private_subnet" {
  value = aws_subnet.vray_privated_subnet[*].id

  description = "Private Network "

}

output "exescript_depends_on_private" {
  value = aws_route_table_association.vray_vpc_us_east2a_privated_association
  #value = []
  #depends_on = [aws_route_table_association.vray_vpc_us_east2a_privated_association]
}

output "exescript_depends_on_public" {
  #value= []
  #value = aws_route_table_association.vray_vpc_us_east2a_privated_association
  value = [aws_route_table_association.vray_vpc_us_east2a_public_association]
}



