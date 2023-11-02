provider "aws" {
  endpoints {
    ec2 = var.endpoint
  }
}

module "key_pair" {
  source   = "../../../../modules/aws/key-pair"
  key_name = var.key_name
  filename = var.filename
}
