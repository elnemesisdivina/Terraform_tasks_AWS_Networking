

#-------check instance IP address generated -------
output "instance_ip_addr" {
  value = aws_instance.vray_instance.private_ip

  description = "The private IP address of the vRay instance."
}



#-------check PK generated fort this instance-------

output "ssh_key" {
  sensitive   = true #can use sensitive_content = to $value to get the key
  description = "ssh key generated on The fly"
  value       = tls_private_key.vray_pk.private_key_pem
}

output "jumpbox_ip_addr" {
  value = aws_instance.vray_jumpbox.public_ip

  description = "The public IP address of the vRay Jumpbox."
}