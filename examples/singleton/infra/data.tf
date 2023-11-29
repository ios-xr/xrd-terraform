data "aws_eks_cluster" "this" {
  name = local.bootstrap.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.bootstrap.outputs.cluster_name
}

data "aws_iam_role" "node" {
  name = data.terraform_remote_state.bootstrap.outputs.node_iam_role_name
}

data "aws_subnet" "cluster" {
  id = data.terraform_remote_state.bootstrap.outputs.private_subnet_ids[0]
}
