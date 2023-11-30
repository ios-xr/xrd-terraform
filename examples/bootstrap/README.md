# Bootstrap configuration

This configuration creates a base set of cloud infrastructure resources:

- VPC
- EKS cluster
- Bastion node (used for access to any subsequently created worker nodes)
- Key pair (assigned to the Bastion and any subsequently created worker nodes)

This must be applied before applying other example configurations.

## Usage

To run this example, execute:

```
terraform init
terraform apply
```

You may then run other example configurations which are layered above the Bootstrap configuration.

When you are finished, make sure you first destroy any other configurations layered above the Bootstrap configuration.  Then to destroy this example, execute:

```
terraform destroy
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.2 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Cluster version | `string` | `"1.28"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Used as a prefix for the 'Name' tag for each created resource.<br>If null, then a random name 'xrd-terraform-[0-9a-z]{8}' is used. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion_instance_id"></a> [bastion\_instance\_id](#output\_bastion\_instance\_id) | Bastion EC2 instance ID |
| <a name="output_bastion_security_group_id"></a> [bastion\_security\_group\_id](#output\_bastion\_security\_group\_id) | Bastion security group ID |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster name |
| <a name="output_key_pair_filename"></a> [key\_pair\_filename](#output\_key\_pair\_filename) | Key pair name.<br>This is assigned to the Bastion instance, and may be assigned to worker node instances. |
| <a name="output_key_pair_name"></a> [key\_pair\_name](#output\_key\_pair\_name) | Key pair name.<br>This is assigned to the Bastion instance, and may be assigned to worker node instances. |
| <a name="output_name_prefix"></a> [name\_prefix](#output\_name\_prefix) | Used as a prefix for the 'Name' tag for each created resource |
| <a name="output_node_iam_instance_profile_name"></a> [node\_iam\_instance\_profile\_name](#output\_node\_iam\_instance\_profile\_name) | Worker node IAM instance profile name |
| <a name="output_node_iam_role_name"></a> [node\_iam\_role\_name](#output\_node\_iam\_role\_name) | Worker node IAM role name |
| <a name="output_oidc_issuer"></a> [oidc\_issuer](#output\_oidc\_issuer) | Cluster OIDC issuer URL |
| <a name="output_oidc_provider"></a> [oidc\_provider](#output\_oidc\_provider) | IAM OIDC provider for the cluster OIDC issuer URL |
| <a name="output_placement_group_name"></a> [placement\_group\_name](#output\_placement\_group\_name) | Placement group name.<br>Worker node instances may be started in this placement group to cluster instances close together. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | Subnet IDs of the two private subnets |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
