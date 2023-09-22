provider "aws" {
  endpoints {
    iam = var.endpoint
  }
}


variable "endpoint" {
  type = string
}

variable "role_name" {
  type        = string
  default     = null
}

variable "role_policies" {
  type        = list(string)
  default     = []
}

variable "oidc_issuer" {
  type        = string
}

variable "oidc_provider" {
  type        = string
}

variable "namespace" {
  type        = string
}

variable "service_account" {
  type        = string
}


module "irsa" {
  source = "../../modules/aws/irsa"

  namespace = var.namespace
  oidc_issuer = var.oidc_issuer
  oidc_provider = var.oidc_provider
  role_name = var.role_name
  role_policies = var.role_policies
  service_account = var.service_account
}


output "role_arn" {
  value = module.irsa.role_arn
}
