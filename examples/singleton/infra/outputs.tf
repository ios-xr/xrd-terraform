output "cluster_name" {
  description = "Cluster name"
  value       = local.bootstrap.cluster_name
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = local.bootstrap.kubeconfig_path
}

output "node_id" {
  description = "Instance ID of the single worker node instance"
  value       = module.node.id
}
