output "cluster_name" {
  value = module.bootstrap.cluster_name
}

output "cluster_version" {
  value = var.cluster_version
}

output "oidc_issuer" {
  value = module.bootstrap.oidc_issuer
}

output "oidc_provider" {
  value = module.bootstrap.oidc_provider
}

output "node_iam_role_name" {
  value = module.bootstrap.node_iam_role_name
}

output "kubeconfig_path" {
  value = "${abspath(path.root)}/.kubeconfig"
}

output "bastion_security_group_id" {
  value = module.bootstrap.bastion_security_group_id
}

output "cluster_security_group_id" {
  value = module.bootstrap.cluster_security_group_id
}

output "vpc_id" {
  value = module.bootstrap.vpc_id
}

output "key_name" {
  value = module.bootstrap.key_name
}

output "node_iam_instance_profile_name" {
  value = module.bootstrap.node_iam_instance_profile_name
}

output "private_subnet_ids" {
  value = module.bootstrap.private_subnet_ids
}

output "name" {
  value = local.name
}

output "placement_group_name" {
  value = module.bootstrap.placement_group_name
}
