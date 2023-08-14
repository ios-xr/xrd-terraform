terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  len_public_subnets  = length(var.public_subnets)
  len_private_subnets = length(var.private_subnets)
  len_intra_subnets   = length(var.intra_subnets)

  max_subnet_length = max(
    local.len_private_subnets,
    local.len_public_subnets,
    local.len_intra_subnets,
  )
}

################################################################################
# VPC
################################################################################

locals {
  create_vpc = var.create_vpc
}

resource "aws_vpc" "this" {
  count = local.create_vpc ? 1 : 0

  cidr_block = var.cidr

  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.vpc_tags,
  )
}

locals {
  vpc_id = try(aws_vpc.this[0].id, null)
}

################################################################################
# Publiс Subnets
################################################################################

locals {
  create_public_subnets = local.create_vpc && local.len_public_subnets > 0
}

resource "aws_subnet" "public" {
  count = local.create_public_subnets ? local.len_public_subnets : 0

  availability_zone       = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id    = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  cidr_block              = element(concat(var.public_subnets, [""]), count.index)
  map_public_ip_on_launch = var.map_public_ip_on_launch
  vpc_id                  = local.vpc_id

  tags = merge(
    {
      Name = try(
        var.public_subnet_names[count.index],
        format("${var.name}-${var.public_subnet_suffix}-%s", element(var.azs, count.index))
      )
    },
    var.tags,
    var.public_subnet_tags,
  )
}

resource "aws_route_table" "public" {
  count = local.create_public_subnets ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = "${var.name}-${var.public_subnet_suffix}" },
    var.tags,
  )
}

resource "aws_route_table_association" "public" {
  count = local.create_public_subnets ? local.len_public_subnets : 0

  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route" "public_internet_gateway" {
  count = local.create_public_subnets && var.create_igw ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

################################################################################
# Private Subnets
################################################################################

locals {
  create_private_subnets = local.create_vpc && local.len_private_subnets > 0

  # Create NAT gateways if necessary: one for each private subnet that has
  # an associated public subnet.
  natgw_count = (
    local.create_private_subnets && local.create_public_subnets && var.enable_nat_gateway ? 
    min(local.len_private_subnets, local.len_public_subnets) : 0
  )
}

resource "aws_subnet" "private" {
  count = local.create_private_subnets ? local.len_private_subnets : 0

  availability_zone    = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  cidr_block           = element(concat(var.private_subnets, [""]), count.index)
  vpc_id               = local.vpc_id

  tags = merge(
    {
      Name = try(
        var.private_subnet_names[count.index],
        format("${var.name}-${var.private_subnet_suffix}-%s", element(var.azs, count.index))
      )
    },
    var.tags,
    var.private_subnet_tags,
  )
}

# There are as many routing tables as the number of NAT gateways.
resource "aws_route_table" "private" {
  count = local.natgw_count

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = "${var.name}-${var.private_subnet_suffix}"
    },
    var.tags,
  )
}

resource "aws_route_table_association" "private" {
  count = local.create_private_subnets ? local.len_private_subnets : 0

  subnet_id = element(aws_subnet.private[*].id, count.index)
  route_table_id = element(aws_route_table.private[*].id, count.index)
}

################################################################################
# Intra Subnets
################################################################################

locals {
  create_intra_subnets = local.create_vpc && local.len_intra_subnets > 0
}

resource "aws_subnet" "intra" {
  count = local.create_intra_subnets ? local.len_intra_subnets : 0

  availability_zone    = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  cidr_block           = element(concat(var.intra_subnets, [""]), count.index)
  vpc_id               = local.vpc_id

  tags = merge(
    {
      Name = try(
        var.intra_subnet_names[count.index],
        format("${var.name}-${var.intra_subnet_suffix}-%s", element(var.azs, count.index))
      )
    },
    var.tags,
    var.intra_subnet_tags,
  )
}

resource "aws_route_table" "intra" {
  count = local.create_intra_subnets ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = "${var.name}-${var.intra_subnet_suffix}" },
    var.tags,
  )
}

resource "aws_route_table_association" "intra" {
  count = local.create_intra_subnets ? local.len_intra_subnets : 0

  subnet_id      = element(aws_subnet.intra[*].id, count.index)
  route_table_id = element(aws_route_table.intra[*].id, 0)
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  count = local.create_public_subnets && var.create_igw ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.igw_tags,
  )
}

################################################################################
# NAT Gateway
################################################################################

locals {
  nat_gateway_ips = try(aws_eip.nat[*].id, [])
}

resource "aws_eip" "nat" {
  count = local.natgw_count

  domain = "vpc"

  tags = merge(
    {
      "Name" = format("${var.name}-%s", element(var.azs, count.index))
    },
    var.tags,
  )
}

resource "aws_nat_gateway" "this" {
  count = local.natgw_count

  allocation_id = element(local.nat_gateway_ips, count.index)
  subnet_id = element(aws_subnet.public[*].id, count.index)

  tags = merge(
    {
      "Name" = format("${var.name}-%s", element(var.azs, count.index))
    },
    var.tags,
    var.nat_gateway_tags,
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat_gateway" {
  count = local.natgw_count

  route_table_id         = element(aws_route_table.private[*].id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, count.index)

  timeouts {
    create = "5m"
  }
}
