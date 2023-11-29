output "cluster_name" {
  description = "Cluster name"
  value       = local.bootstrap.cluster_name
}

output "node_id" {
  description = "Instance ID of the single worker node instance"
  value       = module.node.id
}
