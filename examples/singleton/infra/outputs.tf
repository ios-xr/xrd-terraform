output "kubeconfig_path" {
  value = data.terraform_remote_state.bootstrap.outputs.kubeconfig_path
}

output "node" {
  value = module.node.id
}
