output "bastion_public_ip" {
  value = data.kubernetes_config_map.eks_setup.data.bastion_public_ip
}

output "key_name" {
  value = data.kubernetes_config_map.eks_setup.data.key_name
}

output "key_pair_filename" {
  value = data.kubernetes_config_map.eks_setup.data.key_pair_filename
}

output "cluster_name" {
  value = var.cluster_name
}
