data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_eks_cluster" "this" {
  name = local.bootstrap.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = local.bootstrap.cluster_name
}

data "aws_instance" "alpha" {
  instance_id = local.infra.nodes["alpha"]
}

data "aws_instance" "beta" {
  instance_id = local.infra.nodes["beta"]
}
