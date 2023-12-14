provider "aws" {
  endpoints {
    ec2 = var.aws_endpoint
    eks = var.aws_endpoint
    iam = var.aws_endpoint
  }
}

module "node" {
  source = "../../../../modules/aws/node"

  ami                   = var.ami
  cluster_name          = var.cluster_name
  hugepages_gb          = var.hugepages_gb
  iam_instance_profile  = var.iam_instance_profile
  instance_type         = var.instance_type
  is_xrd_ami            = var.is_xrd_ami
  isolated_cores        = var.isolated_cores
  key_name              = var.key_name
  kubelet_extra_args    = var.kubelet_extra_args
  labels                = var.labels
  name                  = var.name
  network_interfaces    = var.network_interfaces
  placement_group       = var.placement_group
  private_ip_address    = var.private_ip_address
  secondary_private_ips = var.secondary_private_ips
  security_groups       = var.security_groups
  subnet_id             = var.subnet_id
  user_data             = var.user_data
  wait                  = var.wait
  xrd_vr_cp_num_cpus    = var.xrd_vr_cp_num_cpus
  xrd_vr_cpuset         = var.xrd_vr_cpuset
}

output "module" {
  value = module.node
}
