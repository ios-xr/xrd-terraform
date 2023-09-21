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
  type        = string
}

variable "ami" {
  type        = string
}

variable "instance_type" {
  type        = string
  default = "m5.2xlarge"
}

variable "private_ip_address" {
  type        = string
}

variable "security_groups" {
  type        = list(string)
  default = []
}

variable "network_interfaces" {
  type = list(object({
    subnet_id : string
    private_ip_address : string
    security_groups : list(string)
  }))
}

variable "cluster_name" {
  type        = string
}

variable "kubelet_extra_args" {
  type        = string
  default = ""
}

variable "xrd_ami_data" {
  type = object({
    hugepages_gb : number
    isolated_cores : string
  })
  default = null
}

variable "user_data" {
  type        = string
  default = ""
}


data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}


module "vpc" {
  source = "../../modules/aws/vpc"

  name = "${var.cluster_name}-vpc"
  azs  = [data.aws_availability_zones.available.names[0]]
  cidr = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_nat_gateway   = true

  private_subnets         = ["10.0.0.0/24"]
  public_subnets          = ["10.0.200.0/24"]
  map_public_ip_on_launch = true
}


module "key_pair" {
  source = "../../modules/aws/key-pair"

  key_name = "${var.cluster_name}-instance"
  filename = "${abspath(path.root)}/${var.cluster_name}-instance.pem"
}


data "aws_iam_policy_document" "node" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  assume_role_policy = data.aws_iam_policy_document.node.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ]
  name = "${var.cluster_name}-${data.aws_region.current.name}-node"
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.cluster_name}-${data.aws_region.current.name}-node"
  role = aws_iam_role.node.name
}


module "node" {
  source = "../../modules/aws/node"

  wait = false

  # Dependent resources that we need to create.
  iam_instance_profile         = aws_iam_instance_profile.node.name
  key_name      = module.key_pair.key_name
  subnet_id              = module.vpc.private_subnet_ids[0]

  # Parameters.
  ami  = var.ami
  cluster_name = var.cluster_name
  kubelet_extra_args = var.kubelet_extra_args
  instance_type = var.instance_type
  name                    = var.name
  network_interfaces = var.network_interfaces
  private_ip_address              = var.private_ip_address
  security_groups = var.security_groups
  user_data = var.user_data
  xrd_ami_data = var.xrd_ami_data
}


output "id" {
  value       = module.node.id
}

output "private_ip" {
  value       = module.node.private_ip
}
