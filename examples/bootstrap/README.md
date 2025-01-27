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
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azs"></a> [azs](#input\_azs) | List of exactly two availability zones in the currently configured AWS region.<br>A private subnet and a public subnet is created in each of these availability zones.<br>Each cluster node is launched in one of the private subnets.<br>If null, then the first two availability zones in the currently configured AWS region is used. | `list(string)` | `null` | no |
| <a name="input_bastion_remote_access_cidr_blocks"></a> [bastion\_remote\_access\_cidr\_blocks](#input\_bastion\_remote\_access\_cidr\_blocks) | Allowed CIDR blocks for external SSH access to the Bastion instance.<br>This must be a list of strings.<br>If null, then access to the Bastion instance is prevented. | `list(string)` | n/a | yes |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Cluster version | `string` | `"1.32"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Used as a prefix for the 'Name' tag for each created resource.<br>If null, then a random name 'xrd-terraform-[0-9a-z]{8}' is used. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bootstrap"></a> [bootstrap](#output\_bootstrap) | Bootstrap module outputs |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
