provider "aws" {
  endpoints {
    ec2 = var.aws_endpoint
    eks = var.aws_endpoint
    iam = var.aws_endpoint
  }
}

module "eks" {
  source = "../../../../modules/aws/eks"

  name                    = var.name
  endpoint_public_access  = var.endpoint_public_access
  endpoint_private_access = var.endpoint_private_access
  cluster_version         = var.cluster_version
  security_group_ids      = var.security_group_ids
  subnet_ids              = var.subnet_ids
}
