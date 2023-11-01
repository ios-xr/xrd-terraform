provider "aws" {
  endpoints {
    ec2 = var.endpoint
  }
}

module "bastion" {
  source = "../../../modules/aws/bastion"

  subnet_id          = var.subnet_id
  instance_type      = var.instance_type
  key_name           = var.key_name
  name               = var.name
  ami                = var.ami
  security_group_ids = var.security_group_ids
  remote_access_cidr = var.remote_access_cidr
}
