data "terraform_remote_state" "bootstrap" {
  backend = "local"
  config = {
    path = "${path.root}/../../bootstrap/terraform.tfstate"
  }
}

locals {
  bootstrap = data.terraform_remote_state.bootstrap.outputs
}
