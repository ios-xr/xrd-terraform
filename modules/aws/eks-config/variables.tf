variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "oidc_issuer" {
  description = "OIDC issuer URL for the cluster"
  type        = string
}

variable "wait" {
  description = "Whether to wait for resources to roll out"
  type        = bool
  default = true
}
