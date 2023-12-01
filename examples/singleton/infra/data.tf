data "aws_eks_cluster" "this" {
  name = local.bootstrap.cluster_name
}

data "aws_iam_role" "node" {
  name = local.bootstrap.node_iam_role_name
}

data "aws_subnet" "cluster" {
  id = local.bootstrap.private_subnet_ids[0]
}
