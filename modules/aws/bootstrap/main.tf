variable "cluster_version" {
  type    = string
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

variable "name" {
  type     = string
  nullable = false
}

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

resource "aws_subnet" "data" {
  count = length(var.data_subnets)

  availability_zone = element(var.data_subnet_azs, count.index)
  cidr_block        = var.data_subnets[count.index]
  vpc_id            = module.vpc.vpc_id
}

#resource "aws_ec2_subnet_cidr_reservation" "this" {

module "key_pair" {
  source = "../../../modules/aws/key-pair"

  key_name = var.name
  filename = "${abspath(path.root)}/${var.name}.pem"
}

module "eks" {
  source = "../../../modules/aws/eks"

  name               = var.name
  cluster_version    = var.cluster_version
  security_group_ids = []
  subnet_ids         = module.vpc.private_subnet_ids

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

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}

output "bastion_security_group_id" {
  value = module.bastion.security_group_id
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
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

output "oidc_issuer" {
  value = module.eks.oidc_issuer
}

output "oidc_provider" {
  value = aws_iam_openid_connect_provider.this.arn
}

output "node_iam_role_name" {
  value = aws_iam_role.node.name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "placement_group_name" {
  value = aws_placement_group.this.name
}
