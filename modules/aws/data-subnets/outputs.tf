output "cidr_blocks" {
  description = "Map of subnet CIDR blocks, keyed by subnet name"
  value       = { for i, name in local.networks[*].name : name => aws_subnet.this[i].cidr_block }
}

output "ids" {
  description = "Map of subnet IDs, keyed by subnet name"
  value       = { for i, name in local.networks[*].name : name => aws_subnet.this[i].id }
}

output "names" {
  description = "Subnet names"
  value       = local.networks[*].name
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.this.id
}
