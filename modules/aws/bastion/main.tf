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

resource "aws_security_group" "this" {
  name   = "bastion"
  vpc_id = data.aws_subnet.this.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ssh_cidr" {
  for_each = toset(var.remote_access_cidr)

  security_group_id = aws_security_group.this.id

  description = format("SSH ingress traffic from %s", each.value)
  cidr_ipv4   = each.value
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "icmp_cidr" {
  for_each = toset(var.remote_access_cidr)

  security_group_id = aws_security_group.this.id

  description = format("ICMP ingress traffic from %s", each.value)
  cidr_ipv4   = each.value
  from_port   = -1
  to_port     = -1
  ip_protocol = "icmp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id

  description = "All egress traffic"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = -1
  to_port     = -1
  ip_protocol = -1
}

resource "aws_instance" "this" {
  ami           = coalesce(var.ami, data.aws_ami.this.id)
  instance_type = var.instance_type
  key_name      = var.key_name
  vpc_security_group_ids = concat(
    coalesce(var.security_group_ids, [aws_security_group.this.id]),
    [aws_security_group.this.id]
  )
  subnet_id = var.subnet_id
}
