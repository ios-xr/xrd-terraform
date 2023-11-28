output "kubeconfig_path" {
  description = "Path to the kubeconfig file used for cluster access"
  value = data.terraform_remote_state.infra.outputs.kubeconfig_path
}
