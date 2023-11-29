output "bastion_instance_id" {
  description = "Bastion EC2 instance ID"
  value       = module.bootstrap.bastion_instance_id
}

output "bastion_security_group_id" {
  description = "Bastion security group ID"
  value       = module.bootstrap.bastion_security_group_id
}

output "cluster_name" {
  description = "Cluster name"
  value       = module.bootstrap.cluster_name
}

output "key_pair_name" {
  description = <<-EOT
  Key pair name.
  This is assigned to the Bastion instance, and may be assigned to worker node instances.
  EOT
  value       = module.bootstrap.key_pair_name
}

output "key_pair_filename" {
  description = <<-EOT
  Key pair name.
  This is assigned to the Bastion instance, and may be assigned to worker node instances.
  EOT
  value       = module.bootstrap.key_pair_filename
}

output "name_prefix" {
  description = "Used as a prefix for the 'Name' tag for each created resource"
  value       = local.name_prefix
}

output "node_iam_instance_profile_name" {
  description = "Worker node IAM instance profile name"
  value       = module.bootstrap.node_iam_instance_profile_name
}

output "node_iam_role_name" {
  description = "Worker node IAM role name"
  value       = module.bootstrap.node_iam_role_name
}

output "oidc_issuer" {
  description = "Cluster OIDC issuer URL"
  value       = module.bootstrap.oidc_issuer
}

output "oidc_provider" {
  description = "IAM OIDC provider for the cluster OIDC issuer URL"
  value       = module.bootstrap.oidc_provider
}

output "placement_group_name" {
  description = <<-EOT
  Placement group name.
  Worker node instances may be started in this placement group to cluster instances close together.
  EOT
  value       = module.bootstrap.placement_group_name
}

output "private_subnet_ids" {
  description = "Subnet IDs of the two private subnets"
  value       = module.bootstrap.private_subnet_ids
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.bootstrap.vpc_id
}
