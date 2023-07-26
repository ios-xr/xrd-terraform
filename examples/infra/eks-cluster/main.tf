terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.2"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "../../../modules/aws/vpc"

  name = "${var.cluster_name}-vpc"
  azs  = [data.aws_availability_zones.available.names[0]]
  cidr = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_nat_gateway   = true

  private_subnets         = ["10.0.0.0/24"]
  public_subnets          = ["10.0.200.0/24"]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = "10.0.100.0/24"
  vpc_id            = module.vpc.vpc_id
}

resource "aws_ec2_subnet_cidr_reservation" "this" {
  cidr_block       = "10.0.0.0/28"
  reservation_type = "explicit"
  subnet_id        = module.vpc.private_subnet_ids[0]
  description      = "Reservation for worker node primary IPs"
}

module "eks" {
  source = "../../../modules/aws/eks"

  name               = var.cluster_name
  cluster_version    = var.cluster_version
  security_group_ids = []
  subnet_ids         = concat(module.vpc.private_subnet_ids, [aws_subnet.private.id])

  depends_on = [aws_ec2_subnet_cidr_reservation.this]
}
