data "terraform_remote_state" "bootstrap" {
  backend = "local"
  config = {
    path = "${path.root}/../../bootstrap/terraform.tfstate"
  }
}

data "aws_iam_role" "node" {
  name = data.terraform_remote_state.bootstrap.outputs.node_iam_role_name
}

data "aws_subnet" "cluster" {
  id = data.terraform_remote_state.bootstrap.outputs.private_subnet_ids[0]
}
