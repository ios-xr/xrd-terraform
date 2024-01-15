provider "aws" {
  endpoints {
    ec2 = var.aws_endpoint
  }
}

module "data_subnets" {
  source = "../../../../modules/aws/data-subnets"

  availability_zone = var.availability_zone
  name_prefix       = var.name_prefix
  subnet_count      = var.subnet_count
  vpc_id            = var.vpc_id
}

output "module" {
  value = module.data_subnets
}
