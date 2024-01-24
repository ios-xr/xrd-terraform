provider "aws" {
  endpoints {
    ec2 = var.aws_endpoint
    sts = var.aws_endpoint
  }
}

module "key_pair" {
  source   = "../../../../modules/aws/key-pair"
  key_name = var.key_name
  filename = var.filename
}

output "module" {
  value = module.key_pair
}
