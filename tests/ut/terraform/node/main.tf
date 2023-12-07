provider "aws" {
  endpoints {
    ec2 = var.aws_endpoint
    eks = var.aws_endpoint
    iam = var.aws_endpoint
  }
}

module "node" {
  source = "../../../../modules/aws/node"

  wait = false

  ami                  = var.ami
  cluster_name         = var.cluster_name
  iam_instance_profile = var.iam_instance_profile
  instance_type        = var.instance_type
  is_xrd_ami           = var.is_xrd_ami
  key_name             = var.key_name
  kubelet_extra_args   = var.kubelet_extra_args
  name                 = var.name
  network_interfaces   = var.network_interfaces
  private_ip_address   = var.private_ip_address
  security_groups      = var.security_groups
  subnet_id            = var.subnet_id
  user_data            = var.user_data
}

output "module" {
  value = module.node
}
