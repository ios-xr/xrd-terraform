data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_instance" "nodes" {
  for_each = local.infra.nodes

  instance_id = each.value
}
