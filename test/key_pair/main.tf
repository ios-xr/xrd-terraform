variable "key_name" {
  type = string
}

variable "filename" {
  type = string
}

provider "aws" {
  endpoints {
    ec2 = "http://localhost:5000"
  }
}

module "key_pair" {
  source   = "../../modules/aws/key-pair"
  key_name = var.key_name
  filename = var.filename
}
