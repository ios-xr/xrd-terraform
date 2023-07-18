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

    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
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

data "aws_subnet" "public" {
  vpc_id     = data.aws_vpc.this.id
  cidr_block = "10.0.200.0/24"
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

locals {
  create_workload = var.create_nodes && var.create_workload
}

module "eks_config" {
  source = "../../modules/aws/eks-config"

  cluster_name = var.cluster_name
  oidc_issuer  = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_subnet" "data" {
  count = 4

  availability_zone = data.aws_subnet.cluster.availability_zone
  vpc_id            = data.aws_vpc.this.id

  cidr_block = "10.0.${count.index + 1}.0/24"
  # @@@ names
  # access_a, trunk_1, trunk_2, access_b
}

locals {
  public_subnet_id   = data.aws_subnet.public.id
  cluster_subnet_id  = data.aws_subnet.cluster.id
  access_a_subnet_id = aws_subnet.data[0].id
  trunk_1_subnet_id  = aws_subnet.data[1].id
  trunk_2_subnet_id  = aws_subnet.data[2].id
  access_b_subnet_id = aws_subnet.data[3].id

  default_image_repository = format(
    "%s.dkr.ecr.%s.amazonaws.com/xrd/xrd-vrouter",
    data.aws_caller_identity.current.account_id,
    data.aws_region.current.name,
  )
  image_repository = coalesce(var.image_repository, local.default_image_repository)
}

resource "aws_security_group" "comms" {
  name   = "comms"
  vpc_id = data.aws_vpc.this.id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
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

module "key_pair" {
  source = "../../modules/aws/key-pair"

  key_name = "${var.cluster_name}-instance"
  download = true
}

module "bastion" {
  source = "../../modules/aws/bastion"

  count = var.create_bastion ? 1 : 0

  instance_type      = "t3.nano"
  key_name           = module.key_pair.key_name
  security_group_ids = [aws_security_group.comms.id]
  subnet_id          = local.public_subnet_id
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
  source = "../../modules/aws/xrd-ami"
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
        aws_security_group.comms.id,
      ]
      private_ip_address = "10.0.0.11"
      subnet_id          = local.cluster_subnet_id
      network_interfaces = [
        {
          subnet_id          = local.access_a_subnet_id
          private_ip_address = "10.0.1.11"
          security_groups    = [aws_security_group.data.id]
        },
        {
          subnet_id          = local.trunk_1_subnet_id
          private_ip_address = "10.0.2.11"
          security_groups    = [aws_security_group.data.id]
        },
        {
          subnet_id          = local.trunk_2_subnet_id
          private_ip_address = "10.0.3.11"
          security_groups    = [aws_security_group.data.id]
        },
      ]
    }

    beta = {
      ami                = local.xrd_ami
      subnet_id          = local.cluster_subnet_id
      private_ip_address = "10.0.0.12"
      security_groups = [
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
        aws_security_group.comms.id,
      ]
      network_interfaces = [
        {
          subnet_id          = local.access_b_subnet_id
          private_ip_address = "10.0.4.12"
          security_groups    = [aws_security_group.data.id]
        },
        {
          subnet_id          = local.trunk_1_subnet_id
          private_ip_address = "10.0.2.12"
          security_groups    = [aws_security_group.data.id]
        },
        {
          subnet_id          = local.trunk_2_subnet_id
          private_ip_address = "10.0.3.12"
          security_groups    = [aws_security_group.data.id]
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
        aws_security_group.comms.id,
      ]
      network_interfaces = [
        {
          subnet_id          = local.access_a_subnet_id
          private_ip_address = "10.0.1.10"
          security_groups    = [aws_security_group.data.id]
        },
        {
          subnet_id          = local.access_b_subnet_id
          private_ip_address = "10.0.4.10"
          security_groups    = [aws_security_group.data.id]
        },
      ]
    }
  }
}

module "node" {
  source = "../../modules/aws/node"

  for_each = var.create_nodes ? local.nodes : {}

  name                 = each.key
  ami                  = each.value.ami
  cluster_name         = var.cluster_name
  iam_instance_profile = module.eks_config.node_iam_instance_profile_name
  instance_type        = var.node_instance_type
  key_name             = module.key_pair.key_name
  network_interfaces   = each.value.network_interfaces
  private_ip_address   = each.value.private_ip_address
  security_groups      = each.value.security_groups
  subnet_id            = each.value.subnet_id
}

resource "helm_release" "xrd1" {
  count = local.create_workload ? 1 : 0

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

  depends_on = [module.eks_config]
}

resource "helm_release" "xrd2" {
  count = local.create_workload ? 1 : 0

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

  depends_on = [module.eks_config]
}

module "simple_host1" {
  source = "../../modules/aws/simple-host"

  name       = "simple-host1"
  device     = "eth1"
  ip_address = "10.0.1.10/24"
  gateway    = "10.0.1.11"
  routes     = ["10.0.4.0/24"]

  depends_on = [module.eks_config]
}

module "simple_host2" {
  source = "../../modules/aws/simple-host"

  name       = "simple-host2"
  device     = "eth2"
  ip_address = "10.0.4.10/24"
  gateway    = "10.0.4.12"
  routes     = ["10.0.1.0/24"]

  depends_on = [module.eks_config]
}
