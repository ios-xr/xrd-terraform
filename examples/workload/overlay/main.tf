terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.2"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.18"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_vpc" "this" {
  id = data.aws_eks_cluster.this.vpc_config[0].vpc_id
}

data "aws_subnet" "cluster" {
  vpc_id     = data.aws_vpc.this.id
  cidr_block = "10.0.0.0/24"
}

data "aws_security_group" "access" {
  name   = "access"
  vpc_id = data.aws_vpc.this.id
}

data "kubernetes_config_map" "eks_setup" {
  metadata {
    name      = "terraform-eks-setup"
    namespace = "kube-system"
  }
}

provider "helm" {
  repository_config_path = "${path.root}/.helm/repositories.yaml"
  repository_cache       = "${path.root}/.helm"
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
      command     = "aws"
    }
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
  load_config_file = false
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

resource "aws_subnet" "data" {
  for_each = { for i, name in ["access_a", "trunk_1", "trunk_2", "access_b"] : i => name }

  availability_zone = data.aws_subnet.cluster.availability_zone
  cidr_block        = "10.0.${each.key + 1}.0/24"
  vpc_id            = data.aws_vpc.this.id

  tags = {
    Name = each.value
  }
}

locals {
  cluster_subnet_id  = data.aws_subnet.cluster.id
  access_a_subnet_id = aws_subnet.data[0].id
  trunk_1_subnet_id  = aws_subnet.data[1].id
  trunk_2_subnet_id  = aws_subnet.data[2].id
  access_b_subnet_id = aws_subnet.data[3].id

  default_image_registry = format(
    "%s.dkr.ecr.%s.amazonaws.com",
    data.aws_caller_identity.current.account_id,
    data.aws_region.current.name,
  )

  image_repository = format(
    "%s/%s",
    coalesce(var.image_registry, local.default_image_registry),
    var.image_repository,
  )
}

resource "aws_security_group" "data" {
  name   = "data"
  vpc_id = data.aws_vpc.this.id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }
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
  xrd_ami = var.node_ami != null ? var.node_ami : module.xrd_ami[0].id

  nodes = {
    alpha = {
      ami = local.xrd_ami
      security_groups = [
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
        data.aws_security_group.access.id,
      ]
      private_ip_address = "10.0.0.11"
      subnet_id          = local.cluster_subnet_id
      network_interfaces = [
        {
          subnet_id            = local.access_a_subnet_id
          private_ip_addresses = ["10.0.1.11"]
          security_groups      = [aws_security_group.data.id]
        },
        {
          subnet_id            = local.trunk_1_subnet_id
          private_ip_addresses = ["10.0.2.11"]
          security_groups      = [aws_security_group.data.id]
        },
        {
          subnet_id            = local.trunk_2_subnet_id
          private_ip_addresses = ["10.0.3.11"]
          security_groups      = [aws_security_group.data.id]
        },
      ]
    }

    beta = {
      ami                = local.xrd_ami
      subnet_id          = local.cluster_subnet_id
      private_ip_address = "10.0.0.12"
      security_groups = [
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
        data.aws_security_group.access.id,
      ]
      network_interfaces = [
        {
          subnet_id            = local.access_b_subnet_id
          private_ip_addresses = ["10.0.4.12"]
          security_groups      = [aws_security_group.data.id]
        },
        {
          subnet_id            = local.trunk_1_subnet_id
          private_ip_addresses = ["10.0.2.12"]
          security_groups      = [aws_security_group.data.id]
        },
        {
          subnet_id            = local.trunk_2_subnet_id
          private_ip_addresses = ["10.0.3.12"]
          security_groups      = [aws_security_group.data.id]
        },
      ]
    }

    gamma = {
      # This is just running linux containers so could be smaller.
      ami                = data.aws_ami.eks_optimized.id
      subnet_id          = local.cluster_subnet_id
      private_ip_address = "10.0.0.13"
      security_groups = [
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
        data.aws_security_group.access.id,
      ]
      network_interfaces = [
        {
          subnet_id            = local.access_a_subnet_id
          private_ip_addresses = ["10.0.1.10"]
          security_groups      = [aws_security_group.data.id]
        },
        {
          subnet_id            = local.access_b_subnet_id
          private_ip_addresses = ["10.0.4.10"]
          security_groups      = [aws_security_group.data.id]
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
  cluster_name         = var.cluster_name
  iam_instance_profile = data.kubernetes_config_map.eks_setup.data.node_iam_instance_profile_name
  instance_type        = var.node_instance_type
  key_name             = data.kubernetes_config_map.eks_setup.data.key_name
  network_interfaces   = each.value.network_interfaces
  private_ip_address   = each.value.private_ip_address
  security_groups      = each.value.security_groups
  subnet_id            = each.value.subnet_id
}

resource "helm_release" "xrd1" {
  name       = "xrd1"
  repository = "https://ios-xr.github.io/xrd-helm"
  chart      = "xrd-vrouter"

  values = [
    templatefile(
      "${path.module}/templates/xrd1.yaml.tftpl",
      {
        xr_root_user     = var.xr_root_user,
        xr_root_password = var.xr_root_password
        image_repository = local.image_repository
        image_tag        = var.image_tag
        cpuset           = module.node["alpha"].xrd_cpuset
      }
    )
  ]

  depends_on = [module.node["alpha"].ready]
}

resource "helm_release" "xrd2" {
  name       = "xrd2"
  repository = "https://ios-xr.github.io/xrd-helm"
  chart      = "xrd-vrouter"

  values = [
    templatefile(
      "${path.module}/templates/xrd2.yaml.tftpl",
      {
        xr_root_user     = var.xr_root_user,
        xr_root_password = var.xr_root_password
        image_repository = local.image_repository
        image_tag        = var.image_tag
        cpuset           = module.node["beta"].xrd_cpuset
      }
    )
  ]

  depends_on = [module.node["beta"].ready]
}

module "cnf" {
  source = "../../../modules/aws/linux-pod-with-net-attach"

  name       = "cnf"
  device     = "eth1"
  ip_address = "10.0.1.10/24"
  gateway    = "10.0.1.11"
  routes     = ["10.0.4.0/24"]
  node_selector = {
    name = "gamma"
  }

  depends_on = [module.node["gamma"].ready]
}

module "peer" {
  source = "../../../modules/aws/linux-pod-with-net-attach"

  name       = "peer"
  device     = "eth2"
  ip_address = "10.0.4.10/24"
  gateway    = "10.0.4.12"
  routes     = ["10.0.1.0/24"]
  node_selector = {
    name = "gamma"
  }

  depends_on = [module.node["gamma"].ready]
}
