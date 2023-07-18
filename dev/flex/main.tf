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

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.18"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
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

module "eks_config" {
  source = "../../modules/aws/eks-config"

  cluster_name = var.cluster_name
  oidc_issuer  = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

locals {
  create_bastion = var.create_bastion

  intra_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
    "10.0.4.0/24",
    "10.0.5.0/24",
    "10.0.6.0/24",
    "10.0.7.0/24",
    "10.0.8.0/24",
    "10.0.9.0/24",
    "10.0.10.0/24",
    "10.0.11.0/24",
    "10.0.12.0/24",
    "10.0.13.0/24",
    "10.0.14.0/24",
    "10.0.15.0/24",
  ]

  node_names = [for i in range(var.node_count) :
    try(var.node_names[i], format("node%d", i + 1))
  ]
}

resource "aws_subnet" "data" {
  count = var.interface_count

  availability_zone = data.aws_subnet.cluster.availability_zone
  cidr_block        = local.intra_subnets[count.index]
  vpc_id            = data.aws_vpc.this.id
}

data "aws_ec2_instance_type" "current" {
  instance_type = var.node_instance_type

  lifecycle {
    # The number of interfaces requested must be attachable to the
    # requested instance type.
    postcondition {
      condition     = self.maximum_network_interfaces >= var.interface_count
      error_message = "Instance type does not support requested number of interfaces"
    }
  }
}

locals {
  # Use this data source so it's evaluated.
  instance_type = data.aws_ec2_instance_type.current.instance_type
}

locals {
  public_subnet_id    = data.aws_subnet.public.id
  cluster_subnet_id   = data.aws_subnet.cluster.id
  cluster_subnet_cidr = data.aws_subnet.cluster.cidr_block
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

  count = local.create_bastion ? 1 : 0

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

locals {
  nodes = {
    for i in range(var.node_count) :
    local.node_names[i] => {
      private_ip_address = cidrhost(local.cluster_subnet_cidr, i + 11)
      network_interfaces = [
        for j in range(var.interface_count) :
        {
          subnet_id          = aws_subnet.data[j].id
          private_ip_address = cidrhost(aws_subnet.data[j].cidr_block, i + 11)
          security_groups    = [aws_security_group.data.id]
        }
      ]
    }
  }
}

module "node" {
  source   = "../../modules/aws/node"
  for_each = var.create_nodes ? local.nodes : {}

  name                 = each.key
  ami                  = var.node_ami != null ? var.node_ami : module.xrd_ami[0].id
  cluster_name         = var.cluster_name
  iam_instance_profile = module.eks_config.node_iam_instance_profile_name
  instance_type        = local.instance_type
  key_name             = module.key_pair.key_name
  private_ip_address   = each.value.private_ip_address
  security_groups = [
    data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
    aws_security_group.comms.id,
  ]
  subnet_id          = local.cluster_subnet_id
  network_interfaces = each.value.network_interfaces
}

locals {
  create_helm_chart = var.create_nodes && var.create_helm_chart

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

  chart_names = {
    "vRouter" : "xrd-vrouter"
    "ControlPlane" : "xrd-control-plane"
  }
  chart_name = local.chart_names[var.xrd_platform]

  values_template_file = local.vrouter ? "${path.module}/templates/values-vrouter.yaml.tftpl" : "${path.module}/templates/values-control-plane.yaml.tftpl"
}

resource "local_file" "chart_yaml" {
  count = local.create_helm_chart ? 1 : 0

  content = templatefile(
    "${path.module}/templates/Chart.yaml.tftpl",
    {
      xrd_chart            = local.chart_name
      xrd_chart_version    = "~1.0.0-0"
      xrd_chart_repository = "https://ios-xr.github.io/xrd-helm"
      nodes                = local.nodes
    }

  )

  filename = "${path.root}/xrd-flex/Chart.yaml"
}

resource "local_file" "chart_values_yaml" {
  count = local.create_helm_chart ? 1 : 0

  content = templatefile(
    local.values_template_file,
    {
      image_repository = local.image_repository
      image_tag        = var.image_tag
      xr_root_user     = var.xr_root_user
      xr_root_password = var.xr_root_password
      nodes            = local.nodes
      ifname_stem      = local.vrouter ? "HundredGigE" : "GigabitEthernet"
      cpusets          = { for name, out in module.node : name => out.xrd_cpuset }
      hugepages        = { for name, out in module.node : name => out.hugepages_gb }
    }
  )

  filename = "${path.root}/xrd-flex/values.yaml"

  depends_on = [local_file.chart_yaml]

  provisioner "local-exec" {
    command     = "helm dependency update"
    working_dir = "${path.root}/xrd-flex"
  }
}
