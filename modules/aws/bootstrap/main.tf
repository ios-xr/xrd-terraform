module "vpc" {
  source = "../../../modules/aws/vpc"

  name = var.name
  azs  = var.azs
  cidr = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_nat_gateway   = true

  private_subnets         = ["10.0.0.0/24", "10.0.1.0/24"]
  public_subnets          = ["10.0.200.0/24", "10.0.201.0/24"]
  map_public_ip_on_launch = true
}

#resource "aws_ec2_subnet_cidr_reservation" "this" {

module "key_pair" {
  source = "../../../modules/aws/key-pair"

  key_name = var.name
  filename = "${abspath(path.root)}/${var.name}.pem"
}

module "eks" {
  source = "../../../modules/aws/eks"

  name                   = var.name
  cluster_version        = var.cluster_version
  kubeconfig_output_path = "${abspath(path.root)}/.kubeconfig"
  security_group_ids     = []
  subnet_ids             = module.vpc.private_subnet_ids

  #depends_on = [aws_ec2_subnet_cidr_reservation.this]
}

module "bastion" {
  source = "../../../modules/aws/bastion"

  instance_type = "t3.nano"
  key_name      = module.key_pair.key_name
  subnet_id     = module.vpc.public_subnet_ids[0]
  name          = "${var.name}-bastion"
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
  name = "${var.name}-node"
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name}-node"
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

resource "aws_placement_group" "this" {
  name     = var.name
  strategy = "cluster"
}

