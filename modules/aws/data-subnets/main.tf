resource "aws_security_group" "this" {
  name   = "${var.name_prefix}-data"
  vpc_id = var.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    security_groups = [var.bastion_security_group_id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    security_groups = [var.bastion_security_group_id]
  }

  tags = {
    Name = "${var.name_prefix}-data"
  }
}

module "cidr_blocks" {
  source  = "hashicorp/subnets/cidr"
  version = "1.0.0"

  base_cidr_block = data.aws_vpc.this.cidr_block
  networks = concat(
    [
      {
        name     = null
        new_bits = 8
      }
    ],
    [
      for i in range(var.subnet_count) : {
        name     = "${var.name_prefix}-data-${i + 1}"
        new_bits = 8
      }
    ]
  )
}

locals {
  networks = slice(module.cidr_blocks.networks, 1, length(module.cidr_blocks.networks))
}

resource "aws_subnet" "this" {
  count = length(local.networks)

  availability_zone = var.availability_zone
  cidr_block        = local.networks[count.index].cidr_block
  vpc_id            = var.vpc_id

  tags = {
    Name = local.networks[count.index].name
  }
}
