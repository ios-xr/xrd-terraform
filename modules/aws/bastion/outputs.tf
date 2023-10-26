output "id" {
  description = "ID of the bastion EC2 instance"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP of the bastion"
  value       = aws_instance.this.public_ip
}

output "security_group_id" {
  value = aws_security_group.this.id
}
