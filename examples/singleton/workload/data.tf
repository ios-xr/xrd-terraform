data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "${path.root}/../infra/terraform.tfstate"
  }
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.bootstrap.outputs.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.bootstrap.outputs.cluster_name
}

data "aws_instance" "node" {
  instance_id = data.terraform_remote_state.infra.outputs.node_id
}

data "aws_region" "current" {}
