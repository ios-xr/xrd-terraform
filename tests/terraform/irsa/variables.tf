variable "endpoint" {
  type = string
}

variable "role_name" {
  type    = string
  default = null
}

variable "role_policies" {
  type    = list(string)
  default = []
}

variable "oidc_issuer" {
  type = string
}

variable "oidc_provider" {
  type = string
}

variable "namespace" {
  type = string
}

variable "service_account" {
  type = string
}
