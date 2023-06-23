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

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "../../modules/aws/vpc"

  name = "${var.cluster_name}-vpc"
  azs  = [data.aws_availability_zones.available.names[0]]
  cidr = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_nat_gateway   = true

  private_subnets         = ["10.0.101.0/24"]
  public_subnets          = ["10.0.201.0/24"]
  map_public_ip_on_launch = true

  intra_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
  ]

  intra_subnet_names = [
    "data_1",
    "data_2",
    "data_3",
  ]
}

resource "aws_subnet" "private" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = "10.0.102.0/24"
  vpc_id            = module.vpc.vpc_id
}

locals {
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  cluster_subnet_id = module.vpc.private_subnet_ids[0]
  data_1_subnet_id  = module.vpc.intra_subnet_ids[0]
  data_2_subnet_id  = module.vpc.intra_subnet_ids[1]
  data_3_subnet_id  = module.vpc.intra_subnet_ids[2]
}

resource "aws_ec2_subnet_cidr_reservation" "worker_nodes" {
  cidr_block       = "10.0.101.0/28" # 10.0.101.0 - 10.0.101.15
  reservation_type = "explicit"
  subnet_id        = local.cluster_subnet_id
  description      = "Reservation for worker node primary IPs"
}

resource "aws_security_group" "comms" {
  name   = "comms"
  vpc_id = module.vpc.vpc_id
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
  vpc_id = module.vpc.vpc_id
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

module "eks" {
  source = "../../modules/aws/eks"

  name               = var.cluster_name
  cluster_version    = var.cluster_version
  security_group_ids = [aws_security_group.comms.id]
  subnet_ids         = concat(module.vpc.private_subnet_ids, [aws_subnet.private.id])
}

module "xrd_ami" {
  source = "../../modules/aws/xrd-ami"
  count  = var.node_ami == null ? 1 : 0

  cluster_version = var.cluster_version
}

locals {
  xrd_ami = var.node_ami != null ? var.node_ami : module.xrd_ami[0].id
}

module "node" {
  source = "../../modules/aws/node"

  name                 = "alpha"
  ami                  = local.xrd_ami
  cluster_name         = var.cluster_name
  iam_instance_profile = module.eks.node_iam_instance_profile_name
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
  private_ip_address = "10.0.101.10"
  security_groups    = [aws_security_group.comms.id]
  subnet_id          = local.cluster_subnet_id

  depends_on = [module.eks]
}

# Set up the AWS EBS CSI.
# N.B. This requires both a cluster to be set up and nodes to be running,
# as otherwise the AWS EKS addon fails due to not having enough pods running
# in the cluster.
data "aws_iam_policy" "ebs_csi_driver_policy" {
  name = "AmazonEBSCSIDriverPolicy"
}

module "irsa" {
  source = "../../modules/aws/irsa"

  oidc_issuer     = module.eks.oidc_issuer
  oidc_provider   = module.eks.oidc_provider
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_name       = "${var.cluster_name}-${data.aws_region.current.name}-ebs-csi"
  role_policies   = [data.aws_iam_policy.ebs_csi_driver_policy.arn]
}

# If the nodes aren't up when the EBS CSI addon is created, it will
# come up in Degraded state. The AWS addon state is not checked frequently
# and this will either cause a 15 minute(!) delay, or a failure, even
# though all the required pods run as soon as the nodes connect (usually
# around one minute).
#
# This 60 second delay allows the nodes to come up so the required
# EBS CSI controller pods can get scheduled immediately.
resource "time_sleep" "wait_60_seconds" {
  depends_on = [module.node]

  create_duration = "60s"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.18.0-eksbuild.1"
  service_account_role_arn = module.irsa.role_arn

  depends_on = [
    time_sleep.wait_60_seconds
  ]

  timeouts {
    # Cut down the timeout here.
    create = "5m"
  }
}

# Install multus into the cluster.
data "http" "multus_yaml" {
  url = "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/multus/v3.7.2-eksbuild.1/aws-k8s-multus.yaml"
}

provider "kubectl" {
  host                   = module.eks.endpoint
  cluster_ca_certificate = base64decode(module.eks.ca_cert)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.name]
    command     = "aws"
  }
}

data "kubectl_file_documents" "multus" {
  content = data.http.multus_yaml.response_body
}

resource "kubectl_manifest" "multus" {
  for_each = data.kubectl_file_documents.multus.manifests

  yaml_body = each.value

  depends_on = [module.node]
}

# Install the XRd workload into the cluster.
provider "helm" {
  kubernetes {
    host                   = module.eks.endpoint
    cluster_ca_certificate = base64decode(module.eks.ca_cert)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.name]
      command     = "aws"
    }
  }
}

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

  depends_on = [aws_eks_addon.ebs_csi, kubectl_manifest.multus]
}
