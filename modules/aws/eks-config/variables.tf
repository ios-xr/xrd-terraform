variable "cluster_name" {
  description = "Cluster name"
  type        = string
  nullable    = false
}

variable "name_prefix" {
  description = "Used as a prefix for the 'Name' tag for each created resource"
  type        = string
  nullable    = false
}

variable "node_iam_role_arn" {
  description = "Worker node IAM role ARN"
  type        = string
  nullable    = false
}

variable "oidc_issuer" {
  description = "Cluster OIDC issuer URL"
  type        = string
  nullable    = false
}

variable "oidc_provider" {
  description = "IAM OIDC provider for the cluster OIDC issuer URL"
  type        = string
  nullable    = false
}
