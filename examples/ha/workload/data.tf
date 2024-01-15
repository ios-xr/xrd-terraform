data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_instance" "nodes" {
  for_each = local.infra.nodes

  instance_id = each.value
}

data "aws_vpc_endpoint" "ec2" {
  id = local.infra.vpc_endpoint_id
}

data "aws_network_interface" "target" {
  for_each = local.infra.nodes

  filter {
    name   = "attachment.instance-id"
    values = [each.value]
  }

  filter {
    name   = "attachment.device-index"
    values = ["2"]
  }
}
