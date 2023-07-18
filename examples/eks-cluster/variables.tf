variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  nullable    = false
  default     = "xrd-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version to use in the cluster."
  type        = string
  nullable    = false
  default     = "1.27"
}
