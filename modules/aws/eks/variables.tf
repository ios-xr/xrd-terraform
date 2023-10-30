variable "name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes `<major>.<minor>` version to use for the EKS cluster (e.g. `1.28`)"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to allow access to the Kubernetes control plane"
  type        = list(string)
}

variable "subnet_ids" {
  description = "List of subnet IDs (in at least two different AZs) in which to provision EKS cluster control plane ENIs"
  type        = list(string)
}

variable "endpoint_private_access" {
  description = "Whether the Amazon EKS private API server endpoint is enabled. Default is `true`"
  type        = bool
  default     = true
  nullable    = false
}

variable "endpoint_public_access" {
  description = "Whether the Amazon EKS public API server endpoint is eanbled. Default is `true`"
  type        = bool
  default     = true
  nullable    = false
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks allowed to access the public endpoint (when enabled). Defaults to no restriction"
  type        = list(string)
  default     = null
}

variable "kubeconfig_output_path" {
  type = string
  default = null
}
