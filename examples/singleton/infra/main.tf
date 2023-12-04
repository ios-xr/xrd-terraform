provider "aws" {
  default_tags {
    tags = {
      "ios-xr:xrd:terraform"               = "true"
      "ios-xr:xrd:terraform-configuration" = "singleton-infra"
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

locals {
  name_prefix = local.bootstrap.name_prefix
}

module "data_subnets" {
  source = "../../../modules/aws/data-subnets"

  availability_zone   = data.aws_subnet.cluster.availability_zone
  cidr_blocks         = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  security_group_name = "${local.name_prefix}-data"
  names = [
    "${local.name_prefix}-data-1",
    "${local.name_prefix}-data-2",
    "${local.name_prefix}-data-3",
  ]
  vpc_id = local.bootstrap.vpc_id
}

module "eks_config" {
  source = "../../../modules/aws/eks-config"

  oidc_issuer       = local.bootstrap.oidc_issuer
  oidc_provider     = local.bootstrap.oidc_provider
  name_prefix       = local.name_prefix
  node_iam_role_arn = data.aws_iam_role.node.arn
}

module "xrd_ami" {
  source = "../../../modules/aws/xrd-ami"
  count  = var.node_ami == null ? 1 : 0

  cluster_version = data.aws_eks_cluster.this.version
}

locals {
  xrd_ami = var.node_ami != null ? var.node_ami : module.xrd_ami[0].id
}

module "node" {
  source = "../../../modules/aws/node"

  name                 = local.name_prefix
  ami                  = local.xrd_ami
  cluster_name         = local.bootstrap.cluster_name
  iam_instance_profile = local.bootstrap.node_iam_instance_profile_name
  instance_type        = var.node_instance_type
  key_name             = local.bootstrap.key_pair_name
  network_interfaces = [
    {
      subnet_id       = module.data_subnets.ids[0]
      private_ips     = ["10.0.10.10"]
      security_groups = [module.data_subnets.security_group_id]
    },
    {
      subnet_id       = module.data_subnets.ids[1]
      private_ips     = ["10.0.11.10"]
      security_groups = [module.data_subnets.security_group_id]
    },
    {
      subnet_id       = module.data_subnets.ids[2]
      private_ips     = ["10.0.12.10"]
      security_groups = [module.data_subnets.security_group_id]
    },
  ]
  private_ip_address = "10.0.0.10"
  security_groups = [
    local.bootstrap.bastion_security_group_id,
    data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
  ]
  subnet_id = data.aws_subnet.cluster.id
}
