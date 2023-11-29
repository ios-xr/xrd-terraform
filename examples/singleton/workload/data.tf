data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "this" {
  name = local.infra.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = local.infra.cluster_name
}

data "aws_instance" "node" {
  instance_id = local.infra.node_id
}

data "aws_region" "current" {}
