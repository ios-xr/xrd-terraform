data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "${path.root}/../infra/terraform.tfstate"
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_instance" "alpha" {
  instance_id = data.terraform_remote_state.infra.outputs.nodes["alpha"]
}

data "aws_instance" "beta" {
  instance_id = data.terraform_remote_state.infra.outputs.nodes["beta"]
}
