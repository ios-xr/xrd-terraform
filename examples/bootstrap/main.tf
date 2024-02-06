provider "aws" {
  default_tags {
    tags = {
      "ios-xr:xrd:terraform"               = "true"
      "ios-xr:xrd:terraform-configuration" = "bootstrap"
    }
  }
}

module "bootstrap" {
  source = "../../modules/aws/bootstrap"

  azs             = coalesce(var.azs, slice(data.aws_availability_zones.available.names, 0, 2))
  cluster_version = var.cluster_version
  name_prefix     = var.name_prefix
}
