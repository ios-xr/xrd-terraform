provider "aws" {
  default_tags {
    tags = {
      "ios-xr:xrd:terraform"               = "true"
      "ios-xr:xrd:terraform-configuration" = "bootstrap"
    }
  }
}

resource "random_uuid" "name_prefix" {
  count = var.name_prefix == null ? 1 : 0
}

locals {
  name_prefix = var.name_prefix != null ? var.name_prefix : "xrd-terraform-${substr(random_uuid.name_prefix[0].id, 0, 8)}"
}

module "bootstrap" {
  source = "../../modules/aws/bootstrap"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  cluster_version = var.cluster_version
  name_prefix            = local.name_prefix
}
