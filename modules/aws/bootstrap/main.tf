terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.2"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

variable "cluster_version" {
  type = string
  default = "1.27"
}

variable "azs" {
  type = list(string)
}
variable "data_subnet_azs" {
  type = list(string)
}
variable "data_subnets" {
  type = list(string)
}

variable "cluster_name" {
  type = string
  default = "xrd-cluster"
}

data "aws_region" "current" {}

module "vpc" {
  source = "../../../modules/aws/vpc"

  name = "${var.cluster_name}-vpc"
  azs  = var.azs
  cidr = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_nat_gateway   = true

  private_subnets         = ["10.0.0.0/24", "10.0.1.0/24"]
  public_subnets          = ["10.0.200.0/24", "10.0.201.0/24"]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "data" {
  count = length(var.data_subnets)

  availability_zone = element(var.data_subnet_azs, count.index)
  cidr_block        = var.data_subnets[count.index]
  vpc_id            = module.vpc.vpc_id
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

#resource "aws_ec2_subnet_cidr_reservation" "this" {

module "key_pair" {
  source = "../../../modules/aws/key-pair"

  key_name = "${var.cluster_name}-instance"
  filename = "${abspath(path.root)}/${var.cluster_name}-instance.pem"
}

module "eks" {
  source = "../../../modules/aws/eks"

  name               = var.cluster_name
  cluster_version    = var.cluster_version
  security_group_ids = []
  subnet_ids         = module.vpc.private_subnet_ids

  #depends_on = [aws_ec2_subnet_cidr_reservation.this]
}

resource "aws_security_group" "bastion" {
  name   = "bastion"
  vpc_id            = module.vpc.vpc_id
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

module "bastion" {
  source = "../../../modules/aws/bastion"

  instance_type      = "t3.nano"
  key_name           = module.key_pair.key_name
  security_group_ids = [aws_security_group.bastion.id]
  subnet_id          = module.vpc.public_subnet_ids[0]
}

data "aws_iam_policy_document" "node" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  assume_role_policy = data.aws_iam_policy_document.node.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ]
  name = "${var.cluster_name}-${data.aws_region.current.name}-node"
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.cluster_name}-${data.aws_region.current.name}-node"
  role = aws_iam_role.node.name
}

data "tls_certificate" "this" {
  url = module.eks.oidc_issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.this.certificates[*].sha1_fingerprint
  url             = data.tls_certificate.this.url
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}

output "bastion_security_group_id" {
  value = aws_security_group.bastion.id
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "data_security_group_id" {
  value = aws_security_group.data.id
}

output "cluster_name" {
  value = module.eks.name
}

output "node_iam_instance_profile_name" {
  value = aws_iam_instance_profile.node.name
}

output "key_name" {
  value = module.key_pair.key_name
}
output "oidc_provider" {
  value = aws_iam_openid_connect_provider.this.arn
}

output "node_iam_role_name" {
  value = aws_iam_role.node.name
}
