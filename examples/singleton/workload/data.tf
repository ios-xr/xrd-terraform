data "aws_caller_identity" "current" {}

data "aws_instance" "node" {
  instance_id = local.infra.node_id
}

data "aws_region" "current" {}
