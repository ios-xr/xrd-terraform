module "vpc" {
  source = "../../../modules/aws/vpc"

  name = var.name_prefix
  azs  = var.azs
  cidr = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_nat_gateway   = true

  private_subnets         = ["10.0.0.0/24", "10.0.1.0/24"]
  public_subnets          = ["10.0.200.0/24", "10.0.201.0/24"]
  map_public_ip_on_launch = true
}

resource "aws_ec2_subnet_cidr_reservation" "this" {
  cidr_block       = "10.0.0.0/28"
  description      = "Reservation for worker node primary IPs"
  reservation_type = "explicit"
  subnet_id        = module.vpc.private_subnet_ids[0]
}

module "key_pair" {
  source = "../../../modules/aws/key-pair"

  filename = "${abspath(path.root)}/${var.name_prefix}.pem"
  key_name = var.name_prefix
}

module "eks" {
  source = "../../../modules/aws/eks"

  cluster_version = var.cluster_version
  name            = var.name_prefix
  subnet_ids      = module.vpc.private_subnet_ids

  depends_on = [aws_ec2_subnet_cidr_reservation.this]
}

locals {
  kubeconfig_path = coalesce(var.kubeconfig_path, "${abspath(path.root)}/.kubeconfig")
}

resource "null_resource" "kubeconfig" {
  triggers = {
    id = module.eks.id
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.name} --kubeconfig ${local.kubeconfig_path}"
  }
}

module "bastion" {
  source = "../../../modules/aws/bastion"

  instance_type = "t3.nano"
  key_name      = module.key_pair.key_name
  name          = "${var.name_prefix}-bastion"
  subnet_id     = module.vpc.public_subnet_ids[0]
}

resource "aws_iam_role" "node" {
  assume_role_policy = data.aws_iam_policy_document.node.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ]
  name = "${var.name_prefix}-node"
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name_prefix}-node"
  role = aws_iam_role.node.name
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.oidc.certificates[*].sha1_fingerprint
  url             = data.tls_certificate.oidc.url
}

resource "aws_placement_group" "this" {
  name     = var.name_prefix
  strategy = "cluster"
}
