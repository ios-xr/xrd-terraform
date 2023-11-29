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
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token = data.aws_eks_cluster_auth.this.token
}

locals {
  name_prefix = local.bootstrap.name_prefix
}

resource "aws_subnet" "data" {
  for_each = { for i, name in ["data-1", "data-2", "data-3"] : i => name }

  availability_zone = data.aws_subnet.cluster.availability_zone
  cidr_block        = "10.0.${each.key + 10}.0/24"
  vpc_id            = local.bootstrap.vpc_id

  tags = {
    Name = "${local.name_prefix}-${each.value}"
  }
}

resource "aws_security_group" "data" {
  name   = "${local.name_prefix}-data"
  vpc_id = local.bootstrap.vpc_id
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

  tags = {
    Name = "${local.name_prefix}-data"
  }
}

module "eks_config" {
  source = "../../../modules/aws/eks-config"

  cluster_name      = local.bootstrap.cluster_name
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
  data_1_subnet_id = aws_subnet.data[0].id
  data_2_subnet_id = aws_subnet.data[1].id
  data_3_subnet_id = aws_subnet.data[2].id

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
      subnet_id          = local.data_1_subnet_id,
      private_ip_address = "10.0.10.10",
      security_groups    = [aws_security_group.data.id]
    },
    {
      subnet_id          = local.data_2_subnet_id,
      private_ip_address = "10.0.11.10",
      security_groups    = [aws_security_group.data.id]
    },
    {
      subnet_id          = local.data_3_subnet_id,
      private_ip_address = "10.0.12.10",
      security_groups    = [aws_security_group.data.id]
    },
  ]
  private_ip_address = "10.0.0.10"
  security_groups = [
    local.bootstrap.bastion_security_group_id,
    data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
  ]
  subnet_id = data.aws_subnet.cluster.id
}
