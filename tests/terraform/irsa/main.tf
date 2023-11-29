provider "aws" {
  endpoints {
    iam = var.endpoint
  }
}

module "irsa" {
  source = "../../../modules/aws/irsa"

  namespace       = var.namespace
  oidc_issuer     = var.oidc_issuer
  oidc_provider   = var.oidc_provider
  role_name       = var.role_name
  role_policies   = var.role_policies
  service_account = var.service_account
}
