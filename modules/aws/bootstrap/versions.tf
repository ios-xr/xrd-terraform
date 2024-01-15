terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.2"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}
