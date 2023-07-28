provider "aws" {
  endpoints {
    ec2 = "http://localhost:5000"
  }
}

module "vpc" {
  source = "../../modules/aws/vpc"

  create_vpc = var.create_vpc
  name = var.name
  cidr = var.cidr
  azs = var.azs
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support = var.enable_dns_support
  vpc_tags = var.vpc_tags
  tags = var.tags
  public_subnets = var.public_subnets
  map_public_ip_on_launch = var.map_public_ip_on_launch
  public_subnet_names = var.public_subnet_names
  public_subnet_suffix = var.public_subnet_suffix
  public_subnet_tags = var.public_subnet_tags
  private_subnets = var.private_subnets
  private_subnet_names = var.private_subnet_names
  private_subnet_suffix = var.private_subnet_suffix
  private_subnet_tags = var.private_subnet_tags
  intra_subnets = var.intra_subnets
  intra_subnet_names = var.intra_subnet_names
  intra_subnet_suffix = var.intra_subnet_suffix
  intra_subnet_tags = var.intra_subnet_tags
  create_igw = var.create_igw
  igw_tags = var.igw_tags
  enable_nat_gateway = var.enable_nat_gateway
  nat_gateway_tags = var.nat_gateway_tags
}
