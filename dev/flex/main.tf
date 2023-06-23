terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.2"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

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

data "aws_availability_zones" "available" {
  state = "available"
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

module "vpc" {
  source = "../../modules/aws/vpc"

  name = "xrd-cluster-vpc"
  azs  = [data.aws_availability_zones.available.names[0]]
  cidr = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_nat_gateway   = true

  private_subnets         = ["10.0.101.0/24"]
  public_subnets          = ["10.0.201.0/24"]
  map_public_ip_on_launch = true

  intra_subnets = slice(local.intra_subnets, 0, var.interface_count)
}

locals {
  public_subnet_id    = module.vpc.public_subnet_ids[0]
  cluster_subnet_id   = module.vpc.private_subnet_ids[0]
  cluster_subnet_cidr = module.vpc.private_subnet_cidr_blocks[0]
}

resource "aws_subnet" "private" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = "10.0.102.0/24"
  vpc_id            = module.vpc.vpc_id
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

  count = local.create_bastion ? 1 : 0

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
  nodes = {
    for i in range(var.node_count) :
    local.node_names[i] => {
      private_ip_address = cidrhost(local.cluster_subnet_cidr, i + 11)
      network_interfaces = [
        for j in range(var.interface_count) :
        {
          subnet_id          = module.vpc.intra_subnet_ids[j]
          private_ip_address = cidrhost(module.vpc.intra_subnet_cidr_blocks[j], i + 11)
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
  iam_instance_profile = module.eks.node_iam_instance_profile_name
  instance_type        = local.instance_type
  key_name             = module.key_pair.key_name

  private_ip_address = each.value.private_ip_address
  security_groups    = [aws_security_group.comms.id]
  subnet_id          = local.cluster_subnet_id

  network_interfaces = each.value.network_interfaces

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