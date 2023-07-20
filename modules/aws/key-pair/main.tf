terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.4"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = trimspace(tls_private_key.this.public_key_openssh)
}

resource "local_sensitive_file" "this" {
  count           = var.filename ? 1 : 0
  content         = trimspace(tls_private_key.this.private_key_pem)
  filename        = var.filename
  file_permission = "0400"
}
