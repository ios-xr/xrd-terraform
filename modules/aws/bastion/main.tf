terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_ec2_instance_type" "this" {
  instance_type = var.instance_type
}

data "aws_ami" "this" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-minimal-*"]
  }

  filter {
    name   = "architecture"
    values = data.aws_ec2_instance_type.this.supported_architectures
  }

  filter {
    name   = "virtualization-type"
    values = data.aws_ec2_instance_type.this.supported_virtualization_types
  }
}

data "aws_subnet" "this" {
  id = var.subnet_id
}

resource "aws_instance" "this" {
  ami           = coalesce(var.ami, data.aws_ami.this.id)
  instance_type = var.instance_type
  key_name      = var.key_name
  vpc_security_group_ids = var.security_group_ids
  subnet_id = var.subnet_id
}
