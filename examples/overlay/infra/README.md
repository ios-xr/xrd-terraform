<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.2 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.9 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.18 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.9 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_node_ami"></a> [node\_ami](#input\_node\_ami) | n/a | `string` | `null` | no |
| <a name="input_node_instance_type"></a> [node\_instance\_type](#input\_node\_instance\_type) | n/a | `string` | `"m5.2xlarge"` | no |
| <a name="input_placement_group"></a> [placement\_group](#input\_placement\_group) | n/a | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kubeconfig_path"></a> [kubeconfig\_path](#output\_kubeconfig\_path) | Path to the kubeconfig file used for cluster access |
| <a name="output_nodes"></a> [nodes](#output\_nodes) | Map of worker node name to instance ID |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
