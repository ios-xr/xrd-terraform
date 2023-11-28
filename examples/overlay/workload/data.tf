data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "${path.root}/../infra/terraform.tfstate"
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.infra.outputs.cluster_name
}

data "aws_iam_role" "node" {
  name = data.terraform_remote_state.infra.outputs.node_iam_role_name
}

data "aws_instance" "alpha" {
  instance_id = data.terraform_remote_state.infra.outputs.nodes["alpha"]
}

data "aws_instance" "beta" {
  instance_id = data.terraform_remote_state.infra.outputs.nodes["beta"]
}

data "aws_vpc" "this" {
  id = data.aws_eks_cluster.this.vpc_config[0].vpc_id
}
