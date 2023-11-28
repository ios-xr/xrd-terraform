output "kubeconfig_path" {
  description = "Path to the kubeconfig file used for cluster access"
  value = data.terraform_remote_state.bootstrap.outputs.kubeconfig_path
}

output "nodes" {
  description = "Map of worker node name to instance ID"
  value = { for name in keys(local.nodes) : name => module.node[name].id }
}
