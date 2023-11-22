<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.2 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.9 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.18 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_image_registry"></a> [image\_registry](#input\_image\_registry) | Image registry where the XRd container image is hosted. | `string` | `null` | no |
| <a name="input_image_repository"></a> [image\_repository](#input\_image\_repository) | Image repository where the XRd container image is hosted. | `string` | `null` | no |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | Tag of the XRd container image in the repository. | `string` | `"latest"` | no |
| <a name="input_xr_root_password"></a> [xr\_root\_password](#input\_xr\_root\_password) | Root user password to use on XRd instances. | `string` | n/a | yes |
| <a name="input_xr_root_user"></a> [xr\_root\_user](#input\_xr\_root\_user) | Root user name to use on XRd instances. | `string` | n/a | yes |
| <a name="input_xrd_platform"></a> [xrd\_platform](#input\_xrd\_platform) | Which XRd platform to launch. | `string` | `"vRouter"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
