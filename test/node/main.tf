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

variable "ami" {
  type = string
}

variable "iam_instance_profile" {
  type = string
}

variable "key_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "m5.2xlarge"
}

variable "private_ip_address" {
  type = string
}

variable "security_groups" {
  type    = list(string)
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
  type = string
}

variable "kubelet_extra_args" {
  type    = string
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
  type    = string
  default = ""
}


module "node" {
  source = "../../modules/aws/node"

  wait = false

  ami                  = var.ami
  cluster_name         = var.cluster_name
  iam_instance_profile = var.iam_instance_profile
  instance_type        = var.instance_type
  key_name             = var.key_name
  kubelet_extra_args   = var.kubelet_extra_args
  name                 = var.name
  network_interfaces   = var.network_interfaces
  private_ip_address   = var.private_ip_address
  security_groups      = var.security_groups
  subnet_id            = var.subnet_id
  user_data            = var.user_data
  xrd_ami_data         = var.xrd_ami_data
}


output "id" {
  value = module.node.id
}

output "private_ip" {
  value = module.node.private_ip
}
