output "cidr_blocks" {
  description = "Subnet CIDR blocks"
  value       = aws_subnet.this[*].cidr_block
}

output "ids" {
  description = "Subnet IDs"
  value       = aws_subnet.this[*].id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.this.id
}
