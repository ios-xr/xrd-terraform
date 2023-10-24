terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.2"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

variable "node_instance_type" {
  type    = string
  default = "m5.2xlarge"
}
variable "node_ami" {
  type    = string
  default = null
}

variable "cluster_version" {
  type    = string
  default = "1.27"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "bootstrap" {
  source = "../../../modules/aws/bootstrap"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  data_subnet_azs = slice(data.aws_availability_zones.available.names, 0, 1)
  data_subnets    = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

data "aws_ami" "eks_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.cluster_version}-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "xrd_ami" {
  source = "../../../modules/aws/xrd-ami"
  count  = var.node_ami == null ? 1 : 0

  cluster_version = var.cluster_version
}

locals {
  cluster_subnet_id  = module.bootstrap.private_subnet_ids[0]
  access_a_subnet_id = module.bootstrap.data_subnet_ids[0]
  trunk_1_subnet_id  = module.bootstrap.data_subnet_ids[1]
  trunk_2_subnet_id  = module.bootstrap.data_subnet_ids[2]
  access_b_subnet_id = module.bootstrap.data_subnet_ids[3]

  xrd_ami = coalesce(var.node_ami, module.xrd_ami[0].id)

  nodes = {
    alpha = {
      ami           = local.xrd_ami
      instance_type = var.node_instance_type
      security_groups = [
        module.bootstrap.bastion_security_group_id,
        module.bootstrap.cluster_security_group_id,
      ]
      private_ip_address = "10.0.0.11"
      subnet_id          = local.cluster_subnet_id
      network_interfaces = [
        {
          subnet_id          = local.access_a_subnet_id
          private_ip_address = "10.0.10.11"
          security_groups    = [module.bootstrap.data_security_group_id]
        },
        {
          subnet_id          = local.trunk_1_subnet_id
          private_ip_address = "10.0.11.11"
          security_groups    = [module.bootstrap.data_security_group_id]
        },
        {
          subnet_id          = local.trunk_2_subnet_id
          private_ip_address = "10.0.12.11"
          security_groups    = [module.bootstrap.data_security_group_id]
        },
      ]
    }

    beta = {
      ami                = local.xrd_ami
      instance_type      = var.node_instance_type
      subnet_id          = local.cluster_subnet_id
      private_ip_address = "10.0.0.12"
      security_groups = [
        module.bootstrap.bastion_security_group_id,
        module.bootstrap.cluster_security_group_id,
      ]
      network_interfaces = [
        {
          subnet_id          = local.access_b_subnet_id
          private_ip_address = "10.0.13.12"
          security_groups    = [module.bootstrap.data_security_group_id]
        },
        {
          subnet_id          = local.trunk_1_subnet_id
          private_ip_address = "10.0.11.12"
          security_groups    = [module.bootstrap.data_security_group_id]
        },
        {
          subnet_id          = local.trunk_2_subnet_id
          private_ip_address = "10.0.12.12"
          security_groups    = [module.bootstrap.data_security_group_id]
        },
      ]
    }

    gamma = {
      ami = data.aws_ami.eks_optimized.id
      # Used for Alpine Linux containers; m5.large is sufficiently large.
      instance_type      = "m5.large"
      subnet_id          = local.cluster_subnet_id
      private_ip_address = "10.0.0.13"
      security_groups = [
        module.bootstrap.bastion_security_group_id,
        module.bootstrap.cluster_security_group_id,
      ]
      network_interfaces = [
        {
          subnet_id          = local.access_a_subnet_id
          private_ip_address = "10.0.10.10"
          security_groups    = [module.bootstrap.data_security_group_id]
        },
        {
          subnet_id          = local.access_b_subnet_id
          private_ip_address = "10.0.13.10"
          security_groups    = [module.bootstrap.data_security_group_id]
        },
      ]
    }
  }
}

module "node" {
  source = "../../../modules/aws/node"

  for_each = local.nodes

  name                 = each.key
  ami                  = each.value.ami
  cluster_name         = module.bootstrap.cluster_name
  iam_instance_profile = module.bootstrap.node_iam_instance_profile_name
  instance_type        = each.value.instance_type
  key_name             = module.bootstrap.key_name
  network_interfaces   = each.value.network_interfaces
  private_ip_address   = each.value.private_ip_address
  security_groups      = each.value.security_groups
  subnet_id            = each.value.subnet_id
}


output "cluster_name" {
  value = module.bootstrap.cluster_name
}

output "oidc_provider" {
  value = module.bootstrap.oidc_provider
}

output "node_iam_role_name" {
  value = module.bootstrap.node_iam_role_name
}
