variable "aws_endpoint" {
  description = "AWS endpoint URL"
  type        = string
  nullable    = false
}

variable "cluster_version" {
  description = "Desired Kubernetes version for the cluster"
  type        = string
  nullable    = false
}

variable "endpoint_private_access" {
  description = "Whether the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
  nullable    = false
}

variable "endpoint_public_access" {
  description = "Whether the Amazon EKS public API server endpoint is eanbled"
  type        = bool
  default     = true
  nullable    = false
}

variable "name" {
  description = "Cluster name"
  type        = string
}

variable "public_access_cidrs" {
  description = <<-EOT
  List of CIDR blocks allowed to access the public endpoint (when enabled).
  If null, then all CIDR blocks may access the public endpoint.
  EOT
  type        = list(string)
  default     = null
}

variable "security_group_ids" {
  description = "List of security group IDs to allow access to the Kubernetes control plane"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "subnet_ids" {
  description = "List of subnet IDs (in at least two different AZs) in which to provision EKS cluster control plane ENIs"
  type        = list(string)
  nullable    = false
}
