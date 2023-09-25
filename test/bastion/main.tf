provider "aws" {
  endpoints {
    ec2 = var.endpoint
  }
}


variable "endpoint" {
  type = string
}

variable "subnet_id" {
  type        = string
  nullable    = false
}

variable "instance_type" {
  type     = string
  default  = null
}

variable "key_name" {
  type        = string
  nullable    = false
}

variable "ami" {
  type    = string
  default = null
}

variable "security_group_ids" {
  type    = list(string)
  default = null
}

variable "remote_access_cidr" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}


module "bastion" {
  source = "../../modules/aws/bastion"

  subnet_id          = var.subnet_id
  instance_type      = var.instance_type
  key_name           = var.key_name
  ami                = var.ami
  security_group_ids = var.security_group_ids
  remote_access_cidr = var.remote_access_cidr
}


output "id" {
  value = module.bastion.id
}

output "public_ip" {
  value = module.bastion.public_ip
}
