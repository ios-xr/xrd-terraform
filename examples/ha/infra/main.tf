provider "aws" {
  default_tags {
    tags = {
      "ios-xr:xrd:terraform"               = "true"
      "ios-xr:xrd:terraform-configuration" = "ha-infra"
    }
  }
}

provider "helm" {
  repository_config_path = "${path.root}/.helm/repositories.yaml"
  repository_cache       = "${path.root}/.helm"
  kubernetes {
    config_path = local.bootstrap.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = local.bootstrap.kubeconfig_path
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
  cidr_block        = "10.0.${count.index + 10}.0/24"
  vpc_id            = data.aws_vpc.this.id

  tags = {
    Name = "${local.bootstrap.name_prefix}-data-${count.index}"
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

module "eks_config" {
  source = "../../../modules/aws/eks-config"

  name_prefix       = local.bootstrap.name_prefix
  node_iam_role_arn = data.aws_iam_role.node.arn
  oidc_issuer       = local.bootstrap.oidc_issuer
  oidc_provider     = local.bootstrap.oidc_provider
}

module "xrd_ami" {
  source = "../../../modules/aws/xrd-ami"
  count  = var.node_ami == null ? 1 : 0

  cluster_version = data.aws_eks_cluster.this.version

  filters = [
    {
      name   = "tag:Amazon_Linux_Version"
      values = ["AL2023"]
    }
  ]
}

locals {
  placement_group = (
    var.placement_group == null ?
    local.bootstrap.placement_group_name :
    var.placement_group
  )

  xrd_ami = var.node_ami != null ? var.node_ami : module.xrd_ami[0].id

  nodes = {
    alpha = {
      ami                = local.xrd_ami
      private_ip_address = "10.0.100.10"
      subnet_id          = data.aws_subnet.cluster.id

      security_groups = [
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
        local.bootstrap.bastion_security_group_id,
      ]

      network_interfaces = [
        {
          subnet_id       = aws_subnet.data[0].id
          private_ips     = ["10.0.10.10"]
          security_groups = [aws_security_group.data.id]
        },
        {
          subnet_id       = aws_subnet.data[1].id
          private_ips     = ["10.0.11.10"]
          security_groups = [aws_security_group.data.id]
        },
        {
          subnet_id       = aws_subnet.data[2].id
          private_ips     = ["10.0.12.10"]
          security_groups = [aws_security_group.data.id]
        },
      ]
    }

    beta = {
      ami                = local.xrd_ami
      private_ip_address = "10.0.100.11"
      subnet_id          = data.aws_subnet.cluster.id

      security_groups = [
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
        local.bootstrap.bastion_security_group_id,
      ]

      network_interfaces = [
        {
          subnet_id       = aws_subnet.data[0].id
          private_ips     = ["10.0.10.11"]
          security_groups = [aws_security_group.data.id]
        },
        {
          subnet_id       = aws_subnet.data[1].id
          private_ips     = ["10.0.11.11"]
          security_groups = [aws_security_group.data.id]
        },
        {
          subnet_id       = aws_subnet.data[2].id
          private_ips     = ["10.0.12.11"]
          security_groups = [aws_security_group.data.id]
        },
      ]
    }

    gamma = {
      ami                = data.aws_ami.eks_optimized.id
      private_ip_address = "10.0.100.12"
      subnet_id          = data.aws_subnet.cluster.id

      security_groups = [
        data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
        local.bootstrap.bastion_security_group_id,
      ]

      network_interfaces = [
        {
          subnet_id       = aws_subnet.data[0].id
          private_ips     = ["10.0.10.12"]
          security_groups = [aws_security_group.data.id]
        },
        {
          subnet_id       = aws_subnet.data[1].id
          private_ips     = ["10.0.11.12"]
          security_groups = [aws_security_group.data.id]
        },
        {
          subnet_id       = aws_subnet.data[3].id
          private_ips     = ["10.0.13.12"]
          security_groups = [aws_security_group.data.id]
        },
      ]
    }
  }
}

module "node" {
  source = "../../../modules/aws/node"

  for_each = local.nodes

  name                 = "${local.bootstrap.name_prefix}-${each.key}"
  ami                  = each.value.ami
  cluster_name         = local.bootstrap.cluster_name
  iam_instance_profile = local.bootstrap.node_iam_instance_profile_name
  instance_type        = var.node_instance_type
  key_name             = local.bootstrap.key_pair_name
  network_interfaces   = each.value.network_interfaces
  placement_group      = local.placement_group
  private_ip_address   = each.value.private_ip_address
  security_groups      = each.value.security_groups
  subnet_id            = each.value.subnet_id

  labels = {
    name = each.key
  }
}

resource "aws_iam_policy" "ha_app" {
  name   = "${local.bootstrap.name_prefix}-ha-app"
  policy = data.aws_iam_policy_document.ha_app.json
}

module "ha_app_irsa" {
  source = "../../../modules/aws/irsa"

  oidc_issuer     = local.bootstrap.oidc_issuer
  oidc_provider   = local.bootstrap.oidc_provider
  namespace       = "default"
  service_account = "*"
  role_name       = "${local.bootstrap.name_prefix}-ha-app"
  role_policies   = [aws_iam_policy.ha_app.arn]
}
