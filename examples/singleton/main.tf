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

resource "aws_subnet" "data" {
  count = 3

  availability_zone = data.aws_subnet.cluster.availability_zone
  vpc_id            = data.aws_vpc.this.id

  cidr_block = "10.0.${count.index + 1}.0/24"
  # @@@ name
}

locals {
  public_subnet_id  = data.aws_subnet.public.id
  cluster_subnet_id = data.aws_subnet.cluster.id
  data_1_subnet_id  = aws_subnet.data[0].id
  data_2_subnet_id  = aws_subnet.data[1].id
  data_3_subnet_id  = aws_subnet.data[2].id
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

module "xrd_ami" {
  source = "../../modules/aws/xrd-ami"
  count  = var.node_ami == null ? 1 : 0

  cluster_version = var.cluster_version
}

module "eks_config" {
  source = "../../modules/aws/eks-config"

  cluster_name = var.cluster_name
  oidc_issuer  = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

locals {
  xrd_ami = var.node_ami != null ? var.node_ami : module.xrd_ami[0].id
}

module "node" {
  source = "../../modules/aws/node"

  name                 = "alpha"
  ami                  = local.xrd_ami
  cluster_name         = var.cluster_name
  iam_instance_profile = module.eks_config.node_iam_instance_profile_name
  instance_type        = var.node_instance_type
  key_name             = module.key_pair.key_name
  network_interfaces = [
    {
      subnet_id          = local.data_1_subnet_id,
      private_ip_address = "10.0.1.10",
      security_groups    = [aws_security_group.data.id]
    },
    {
      subnet_id          = local.data_2_subnet_id,
      private_ip_address = "10.0.2.10",
      security_groups    = [aws_security_group.data.id]
    },
    {
      subnet_id          = local.data_3_subnet_id,
      private_ip_address = "10.0.3.10",
      security_groups    = [aws_security_group.data.id]
    },
  ]
  private_ip_address = "10.0.0.10"
  security_groups    = [
    data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
    aws_security_group.comms.id,
  ]
  subnet_id          = local.cluster_subnet_id
}

# Install the XRd workload into the cluster.
locals {
  create_workload = var.create_nodes && var.create_workload

  vrouter = var.xrd_platform == "vRouter"

  default_repo_names = {
    "vRouter" : "xrd/xrd-vrouter"
    "ControlPlane" : "xrd/xrd-control-plane"
  }
  default_image_repository = format(
    "%s.dkr.ecr.%s.amazonaws.com/%s",
    data.aws_caller_identity.current.account_id,
    data.aws_region.current.name,
    local.default_repo_names[var.xrd_platform]
  )
  image_repository = coalesce(var.image_repository, local.default_image_repository)
}

resource "helm_release" "xrd1" {
  count = local.create_workload ? 1 : 0

  name       = "xrd1"
  repository = "https://ios-xr.github.io/xrd-helm"
  chart      = local.vrouter ? "xrd-vrouter" : "xrd-control-plane"
  wait       = false

  values = [
    templatefile(
      local.vrouter ? "${path.module}/templates/xrd-vr.yaml.tftpl" : "${path.module}/templates/xrd-cp.yaml.tftpl",
      {
        node_name                = "alpha"
        image_repository         = local.image_repository
        image_tag                = var.image_tag
        xr_root_user             = var.xr_root_user
        xr_root_password         = var.xr_root_password
        loopback_ip              = "1.1.1.1"
        interface_count          = 3
        interface_ipv4_addresses = ["10.0.1.10", "10.0.2.10", "10.0.3.10"]
        cpuset                   = module.node.xrd_cpuset
      }
    )
  ]

  depends_on = [module.eks_config]
}
