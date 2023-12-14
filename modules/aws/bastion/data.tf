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

data "aws_ec2_instance_type" "this" {
  instance_type = var.instance_type
}

data "aws_subnet" "this" {
  id = var.subnet_id
}
