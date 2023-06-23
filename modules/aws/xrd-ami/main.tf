terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_ami" "this" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "tag:Generated_By"
    values = ["xrd-packer"]
  }

  filter {
    name   = "tag:Kubernetes_Version"
    values = [var.cluster_version]
  }

  dynamic "filter" {
    for_each = var.filters
    content {
      name   = filter.value["name"]
      values = filter.value["values"]
    }
  }
}
