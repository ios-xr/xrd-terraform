resource "aws_security_group" "this" {
  name   = var.security_group_name
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
    Name = var.security_group_name
  }
}

resource "aws_subnet" "this" {
  count = length(var.cidr_blocks)

  availability_zone = var.availability_zone
  cidr_block        = var.cidr_blocks[count.index]
  vpc_id            = var.vpc_id

  tags = {
    Name = var.names[count.index]
  }
}
