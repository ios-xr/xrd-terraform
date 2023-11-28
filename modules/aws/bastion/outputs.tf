output "id" {
  description = "Bastion EC2 instance ID"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Bastion public IP address"
  value       = aws_instance.this.public_ip
}

output "security_group_id" {
  description = "Bastion security group ID"
  value       = aws_security_group.this.id
}
