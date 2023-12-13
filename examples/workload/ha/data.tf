data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_vpc" "this" {
  id = data.aws_eks_cluster.this.vpc_config[0].vpc_id
}

data "aws_subnet" "cluster" {
  vpc_id     = data.aws_vpc.this.id
  cidr_block = "10.0.0.0/24"
}

data "aws_security_group" "access" {
  name   = "access"
  vpc_id = data.aws_vpc.this.id
}

data "kubernetes_config_map" "eks_setup" {
  metadata {
    name      = "terraform-eks-setup"
    namespace = "kube-system"
  }
}
