<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.2 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.9 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.18 |
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
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | n/a |
| <a name="output_kubeconfig_path"></a> [kubeconfig\_path](#output\_kubeconfig\_path) | n/a |
| <a name="output_node_iam_role_name"></a> [node\_iam\_role\_name](#output\_node\_iam\_role\_name) | n/a |
| <a name="output_nodes"></a> [nodes](#output\_nodes) | n/a |
| <a name="output_oidc_provider"></a> [oidc\_provider](#output\_oidc\_provider) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
