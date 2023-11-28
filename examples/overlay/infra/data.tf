data "terraform_remote_state" "bootstrap" {
  backend = "local"
  config = {
    path = "${path.root}/../../bootstrap/terraform.tfstate"
  }
}

data "aws_ami" "eks_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${data.terraform_remote_state.bootstrap.outputs.cluster_version}-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.bootstrap.outputs.cluster_name
}

data "aws_iam_role" "node" {
  name = data.terraform_remote_state.bootstrap.outputs.node_iam_role_name
}

data "aws_subnet" "cluster" {
  id = data.terraform_remote_state.bootstrap.outputs.private_subnet_ids[0]
}
