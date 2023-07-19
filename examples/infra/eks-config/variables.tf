variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  nullable    = false
  default     = "xrd-cluster"
}

variable "wait" {
  description = "Whether to wait for resources to roll out"
  type        = bool
  nullable    = false
  default     = true
}
