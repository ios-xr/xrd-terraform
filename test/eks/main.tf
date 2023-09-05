provider "aws" {
  endpoints {
    ec2 = var.endpoint
    eks = var.endpoint
    iam = var.endpoint
  }
}

variable "endpoint" {
  type = string
}

variable "name" {
  type    = string
}

variable "cluster_version" {
  type    = string
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "public_access_cidrs" {
  type    = list(string)
  default = null
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "one" {
  vpc_id     = aws_vpc.this.id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.10.0/24"
}

resource "aws_subnet" "two" {
  vpc_id     = aws_vpc.this.id
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block = "10.0.11.0/24"
}

module "eks" {
  source = "../../modules/aws/eks"

  name = var.name
  cluster_version = var.cluster_version
  security_group_ids = var.security_group_ids
  subnet_ids = [aws_subnet.one.id, aws_subnet.two.id]
}
