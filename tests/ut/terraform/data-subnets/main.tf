provider "aws" {
  endpoints {
    ec2 = var.aws_endpoint
    sts = var.aws_endpoint
  }
}

resource "aws_security_group" "bastion" {
  name   = "bastion_security_group_id"
  vpc_id = var.vpc_id
}

module "data_subnets" {
  source = "../../../../modules/aws/data-subnets"

  availability_zone         = var.availability_zone
  name_prefix               = var.name_prefix
  subnet_count              = var.subnet_count
  vpc_id                    = var.vpc_id
  bastion_security_group_id = aws_security_group.bastion.id
}

output "module" {
  value = merge(
    module.data_subnets,
    {
      "bastion_security_group_id" : aws_security_group.bastion.id
    }
  )
}
