data "aws_availability_zones" "available" {
  state = "available"
}

resource "random_uuid" "name" {
  count = var.name == null ? 1 : 0
}

locals {
  name = var.name != null ? var.name : "xrd-terraform-${substr(random_uuid.name[0].id, 0, 8)}"
}

module "bootstrap" {
  source = "../../modules/aws/bootstrap"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  cluster_version = var.cluster_version
  name            = local.name
}
