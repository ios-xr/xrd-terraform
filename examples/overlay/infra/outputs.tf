output "cluster_name" {
  value = data.terraform_remote_state.bootstrap.outputs.cluster_name
}

output "oidc_provider" {
  value = data.terraform_remote_state.bootstrap.outputs.oidc_provider
}

output "node_iam_role_name" {
  value = data.terraform_remote_state.bootstrap.outputs.node_iam_role_name
}

output "kubeconfig_path" {
  value = data.terraform_remote_state.bootstrap.outputs.kubeconfig_path
}

output "nodes" {
  value = { for name in keys(local.nodes) : name => module.node[name].id }
}
