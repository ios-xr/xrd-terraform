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

resource "aws_subnet" "this" {
  count = length(module.cidr_blocks.networks)

  availability_zone = var.availability_zone
  cidr_block        = module.cidr_blocks.networks[count.index].cidr_block
  vpc_id            = var.vpc_id

  tags = {
    Name = module.cidr_blocks.networks[count.index].name
  }
}
