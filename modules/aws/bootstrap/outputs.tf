output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "bastion_security_group_id" {
  description = "Bastion security group ID"
  value       = module.bastion.security_group_id
}

output "cluster_name" {
  description = "Cluster name"
  value       = module.eks.name
}

output "node_iam_instance_profile_name" {
  description = "Name of the IAM instance profile suitable for use by node instances"
  value       = aws_iam_instance_profile.node.name
}

output "key_name" {
  description = "Name of the key pair assigned to the Bastion host"
  value       = module.key_pair.key_name
}

output "oidc_issuer" {
  description = "Cluster OIDC issuer"
  value       = module.eks.oidc_issuer
}

output "oidc_provider" {
  description = "Cluster OIDC provider"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "node_iam_role_name" {
  description = "Name of the IAM role suitable for use by node instances"
  value       = aws_iam_role.node.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "placement_group_name" {
  description = "Placement group name"
  value       = aws_placement_group.this.name
}
