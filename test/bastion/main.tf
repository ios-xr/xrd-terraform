provider "aws" {
  endpoints {
    ec2 = "http://localhost:5000"
  }
}

variable "instance_type" {
  type     = string
  default  = "t3.nano"
  nullable = false
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

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "this" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "10.0.0.0/24"
}

resource "aws_security_group" "ssh" {}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.ssh.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22
}

resource "random_uuid" "this" {}

module "key_pair" {
  source = "../../modules/aws/key-pair"

  key_name = random_uuid.this.id
  filename = "${abspath(path.root)}/${random_uuid.this.id}.pem"
}

module "bastion" {
  source = "../../modules/aws/bastion"

  subnet_id          = aws_subnet.this.id
  instance_type      = var.instance_type
  key_name           = module.key_pair.key_name
  ami                = var.ami
  security_group_ids = var.security_group_ids
  remote_access_cidr = var.remote_access_cidr
}

output "key_pair_filename" {
  value = module.key_pair.filename
}

output "id" {
  value = module.bastion.id
}

output "public_ip" {
  value = module.bastion.public_ip
}
