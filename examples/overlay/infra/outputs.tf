output "cluster_name" {
  description = "Cluster name"
  value       = local.bootstrap.cluster_name
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = local.bootstrap.kubeconfig_path
}

output "nodes" {
  description = "Map of worker node name to instance ID"
  value       = { for name in keys(local.nodes) : name => module.node[name].id }
}
