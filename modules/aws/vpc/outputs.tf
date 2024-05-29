################################################################################
# VPC
################################################################################

output "vpc_id" {
  description = "The ID of the VPC"
  value       = try(aws_vpc.this[0].id, null)
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = try(aws_vpc.this[0].cidr_block, null)
}

################################################################################
# Internet Gateway
################################################################################

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = try(aws_internet_gateway.this[0].id, null)
}

################################################################################
# Publiс Subnets
################################################################################

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidr_blocks" {
  description = "List of CIDR blocks of public subnets"
  value       = compact(aws_subnet.public[*].cidr_block)
}

################################################################################
# Private Subnets
################################################################################

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidr_blocks" {
  description = "List of CIDR blocks of private subnets"
  value       = compact(aws_subnet.private[*].cidr_block)
}

################################################################################
# Intra Subnets
################################################################################

output "intra_subnet_ids" {
  description = "List of IDs of intra subnets"
  value       = aws_subnet.intra[*].id
}

output "intra_subnet_cidr_blocks" {
  description = "List of CIDR blocks of intra subnets"
  value       = compact(aws_subnet.intra[*].cidr_block)
}

################################################################################
# NAT Gateway
################################################################################

output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = aws_eip.nat[*].public_ip
}

output "natgw_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.this[*].id
}

################################################################################
# Static values (arguments)
################################################################################

output "azs" {
  description = "A list of availability zones specified as argument to this module"
  value       = var.azs
}

output "name" {
  description = "The name of the VPC specified as argument to this module"
  value       = var.name
}

output "ipv6_cidr_block" {
  value       = aws_vpc.this[0].ipv6_cidr_block
}
