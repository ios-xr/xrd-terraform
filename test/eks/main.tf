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
  type = string
}

variable "cluster_version" {
  type = string
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "endpoint_public_access" {
  type    = bool
  default = null
}

variable "endpoint_private_access" {
  type    = bool
  default = null
}

variable "public_access_cidrs" {
  type    = list(string)
  default = null
}

variable "subnet_ids" {
  type = list(string)
}


module "eks" {
  source = "../../modules/aws/eks"

  name                    = var.name
  endpoint_public_access  = var.endpoint_public_access
  endpoint_private_access = var.endpoint_private_access
  cluster_version         = var.cluster_version
  security_group_ids      = var.security_group_ids
  subnet_ids              = var.subnet_ids
}
