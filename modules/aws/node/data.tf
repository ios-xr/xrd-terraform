data "aws_ami" "this" {
  filter {
    name   = "image-id"
    values = [var.ami]
  }
}

data "aws_ec2_instance_type" "this" {
  instance_type = var.instance_type
}
