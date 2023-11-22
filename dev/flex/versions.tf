terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.2"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.18"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }

    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}
