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

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.18"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
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

resource "aws_vpc_endpoint" "ec2" {
  private_dns_enabled = true
  security_group_ids  = [data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2"
  subnet_ids          = [data.aws_subnet.cluster.id]
  vpc_endpoint_type   = "Interface"
  vpc_id              = data.aws_vpc.this.id
}

resource "aws_route_table" "cnf_vrid2" {
  vpc_id = data.aws_vpc.this.id

  tags = {
    Name = "cnf-vrid2"
  }
}

resource "aws_route_table_association" "cnf_vrid2" {
  route_table_id = aws_route_table.cnf_vrid2.id
  subnet_id      = aws_subnet.data[3].id
}

resource "aws_subnet" "data" {
  count = 4

  availability_zone = data.aws_subnet.cluster.availability_zone
  vpc_id            = data.aws_vpc.this.id

  cidr_block = "10.0.${count.index + 10}.0/24"
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
      ami                = local.xrd_ami
      subnet_id          = data.aws_subnet.cluster.id
      private_ip_address = "10.0.0.10"
      security_groups = [
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
        data.aws_security_group.access.id,
      ]
      network_interfaces = [
        {
          subnet_id            = aws_subnet.data[0].id
          private_ip_addresses = ["10.0.10.10"]
          security_groups = [
            data.aws_security_group.access.id,
            aws_security_group.data.id,
          ]
        },
        {
          subnet_id            = aws_subnet.data[1].id
          private_ip_addresses = ["10.0.11.10"]
          security_groups      = [aws_security_group.data.id]
        },
        {
          subnet_id            = aws_subnet.data[2].id
          private_ip_addresses = ["10.0.12.10"]
          security_groups      = [aws_security_group.data.id]
        },
      ]
    }

    beta = {
      ami                = local.xrd_ami
      subnet_id          = data.aws_subnet.cluster.id
      private_ip_address = "10.0.0.11"
      security_groups = [
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
        data.aws_security_group.access.id,
      ]
      network_interfaces = [
        {
          subnet_id            = aws_subnet.data[0].id
          private_ip_addresses = ["10.0.10.11"]
          security_groups = [
            data.aws_security_group.access.id,
            aws_security_group.data.id,
          ]
        },
        {
          subnet_id            = aws_subnet.data[1].id
          private_ip_addresses = ["10.0.11.11"]
          security_groups      = [aws_security_group.data.id]
        },
        {
          subnet_id            = aws_subnet.data[2].id
          private_ip_addresses = ["10.0.12.11"]
          security_groups      = [aws_security_group.data.id]
        },
      ]
    }

    gamma = {
      ami                = data.aws_ami.eks_optimized.id
      subnet_id          = data.aws_subnet.cluster.id
      private_ip_address = "10.0.0.12"
      security_groups = [
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
        data.aws_security_group.access.id,
      ]
      network_interfaces = [
        {
          subnet_id            = aws_subnet.data[0].id
          private_ip_addresses = ["10.0.10.12"]
          security_groups      = [aws_security_group.data.id]
        },
        {
          subnet_id            = aws_subnet.data[1].id
          private_ip_addresses = ["10.0.11.12"]
          security_groups      = [aws_security_group.data.id]
        },
        {
          subnet_id            = aws_subnet.data[3].id
          private_ip_addresses = ["10.0.13.12"]
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

locals {
  default_image_registry = format(
    "%s.dkr.ecr.%s.amazonaws.com",
    data.aws_caller_identity.current.account_id,
    data.aws_region.current.name,
  )

  xrd_image = format(
    "%s/%s",
    coalesce(var.xrd_image_registry, local.default_image_registry),
    var.xrd_image_repository,
  )

  ha_app_image = format(
    "%s/%s",
    coalesce(var.ha_app_image_registry, local.default_image_registry),
    var.ha_app_image_repository,
  )
}

data "aws_iam_policy_document" "ha_app" {
  # Allow describing (read-only) all EC2 instances and network interfaces.
  statement {
    actions   = ["ec2:DescribeInstances", "ec2:DescribeNetworkInterfaces", "ec2:DescribeRouteTables"]
    resources = ["*"]
  }

  # Allow route modification on only the access route table created above.
  statement {
    actions = ["ec2:CreateRoute", "ec2:DeleteRoute", "ec2:ReplaceRoute"]
    resources = [format(
      "arn:aws:ec2:%s:%s:route-table/%s",
      data.aws_region.current.name,
      data.aws_caller_identity.current.account_id,
      aws_route_table.cnf_vrid2.id,
    )]
  }

  # Allow IP [un]assignment on all network interfaces owned by the account
  # in the current region.
  statement {
    actions = ["ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses"]
    resources = [format(
      "arn:aws:ec2:%s:%s:network-interface/*",
      data.aws_region.current.name,
      data.aws_caller_identity.current.account_id,
    )]
  }
}

resource "aws_iam_policy" "ha_app" {
  name   = "${var.cluster_name}-${data.aws_region.current.name}-ha-app"
  policy = data.aws_iam_policy_document.ha_app.json
}

module "ha_irsa" {
  source = "../../../modules/aws/irsa"

  oidc_issuer     = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  oidc_provider   = data.kubernetes_config_map.eks_setup.data.oidc_provider
  namespace       = "default"
  service_account = "*"
  role_name       = "${var.cluster_name}-${data.aws_region.current.name}-ha-app"
  role_policies   = [aws_iam_policy.ha_app.arn]
}

resource "helm_release" "xrd1" {
  name       = "xrd1"
  repository = var.ha_app_chart_repository
  chart      = var.ha_app_chart_name

  values = [
    templatefile(
      "${path.module}/templates/xrd1.yaml.tftpl",
      {
        ha_app_role_arn          = module.ha_irsa.role_arn
        ec2_endpoint_url         = aws_vpc_endpoint.ec2.dns_entry[0].dns_name
        xrd_image_repository     = local.xrd_image
        xrd_image_tag            = var.xrd_image_tag
        ha_app_image_repository  = local.ha_app_image
        ha_app_image_tag         = var.ha_app_image_tag
        xr_root_user             = var.xr_root_user
        xr_root_password         = var.xr_root_password
        route_table_id           = aws_route_table.cnf_vrid2.id
        target_network_interface = module.node["alpha"].network_interface[2].id
      }
    )
  ]

  depends_on = [module.node["alpha"].ready]
}

resource "helm_release" "xrd2" {
  name       = "xrd2"
  repository = var.ha_app_chart_repository
  chart      = var.ha_app_chart_name

  values = [
    templatefile(
      "${path.module}/templates/xrd2.yaml.tftpl",
      {
        ha_app_role_arn          = module.ha_irsa.role_arn
        ec2_endpoint_url         = aws_vpc_endpoint.ec2.dns_entry[0].dns_name
        xrd_image_repository     = local.xrd_image
        xrd_image_tag            = var.xrd_image_tag
        ha_app_image_repository  = local.ha_app_image
        ha_app_image_tag         = var.ha_app_image_tag
        xr_root_user             = var.xr_root_user
        xr_root_password         = var.xr_root_password
        route_table_id           = aws_route_table.cnf_vrid2.id
        target_network_interface = module.node["beta"].network_interface[2].id
      }
    )
  ]

  depends_on = [module.node["beta"].ready]
}

module "peer" {
  source = "../../../modules/aws/linux-pod-with-net-attach"

  name       = "peer"
  device     = "eth1"
  ip_address = "10.0.10.12/24"
  gateway    = "10.0.10.20"
  routes     = ["10.0.11.0/24", "10.0.13.0/24"]
  node_selector = {
    name = "gamma"
  }

  depends_on = [module.node["gamma"].ready]
}

module "cnf_vrid1" {
  source = "../../../modules/aws/linux-pod-with-net-attach"

  name       = "cnf-vrid1"
  device     = "eth2"
  ip_address = "10.0.11.12/24"
  gateway    = "10.0.11.20"
  routes     = ["10.0.10.0/24"]
  node_selector = {
    name = "gamma"
  }

  depends_on = [module.node["gamma"].ready]
}

module "cnf_vrid2" {
  source = "../../../modules/aws/linux-pod-with-net-attach"

  name       = "cnf-vrid2"
  device     = "eth3"
  ip_address = "10.0.13.12/24"
  gateway    = "10.0.13.1"
  routes     = ["10.0.10.0/24"]
  node_selector = {
    name = "gamma"
  }

  depends_on = [module.node["gamma"].ready]
}
