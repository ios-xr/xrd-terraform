output "kubeconfig_path" {
  description = "Path to the kubeconfig file used for cluster access"
  value       = data.terraform_remote_state.bootstrap.outputs.kubeconfig_path
}

output "node_id" {
  description = "Instance ID of the single worker node instance"
  value       = module.node.id
}
