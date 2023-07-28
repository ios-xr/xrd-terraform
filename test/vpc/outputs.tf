output "vpc_id" {
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value       = module.vpc.vpc_cidr_block
}

output "igw_id" {
  value       = module.vpc.igw_id
}

output "public_subnet_ids" {
  value       = module.vpc.public_subnet_ids
}

output "public_subnet_cidr_blocks" {
  value       = module.vpc.public_subnet_cidr_blocks
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
}

output "private_subnet_cidr_blocks" {
  value       = module.vpc.private_subnet_cidr_blocks
}

output "intra_subnet_ids" {
  value       = module.vpc.intra_subnet_ids
}

output "intra_subnet_cidr_blocks" {
  value       = module.vpc.intra_subnet_cidr_blocks
}

output "nat_public_ips" {
  value       = module.vpc.nat_public_ips
}

output "natgw_ids" {
  value       = module.vpc.natgw_ids
}

output "azs" {
  value       = module.vpc.azs
}

output "name" {
  value       = module.vpc.name
}
