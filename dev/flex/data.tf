data "terraform_remote_state" "bootstrap" {
  backend = "local"
  config = {
    path = "${path.root}/../../examples/bootstrap/terraform.tfstate"
  }
}

data "aws_caller_identity" "current" {}

data "aws_ec2_instance_type" "current" {
  instance_type = var.node_instance_type

  lifecycle {
    # The number of interfaces requested must be attachable to the
    # requested instance type.
    postcondition {
      condition     = self.maximum_network_interfaces >= var.interface_count
      error_message = "Instance type does not support requested number of interfaces"
    }
  }
}

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.bootstrap.outputs.cluster_name
}

data "aws_iam_role" "node" {
  name = data.terraform_remote_state.bootstrap.outputs.node_iam_role_name
}

data "aws_region" "current" {}

data "aws_subnet" "cluster" {
  id = data.terraform_remote_state.bootstrap.outputs.private_subnet_ids[0]
}
