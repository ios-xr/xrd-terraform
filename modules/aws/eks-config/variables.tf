variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "node_iam_role_arn" {
  type = string
}

variable "oidc_issuer" {
  description = "OIDC issuer URL for the cluster"
  type        = string
}

variable "oidc_provider" {
  type = string
}
