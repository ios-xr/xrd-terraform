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
  default     = "1.28"
}

variable "node_ami" {
  description = "Custom AMI to use for the worker nodes."
  type        = string
  default     = null
}

variable "node_instance_type" {
  description = "EC2 instance type to use for worker nodes."
  type        = string
  default     = "m5.2xlarge"

  validation {
    condition     = contains(["m5.2xlarge", "m5n.2xlarge", "m5.24xlarge", "m5n.24xlarge"], var.node_instance_type)
    error_message = "Allowed values are m5.2xlarge, m5n.2xlarge, m5.24xlarge, m5n.24xlarge"
  }
}

variable "xr_root_user" {
  description = "Root user name to use on XRd instances."
  type        = string
  nullable    = false
}

variable "xr_root_password" {
  description = "Root user password to use on XRd instances."
  type        = string
  nullable    = false
}

variable "image_registry" {
  description = "Image registry where the XRd container image is hosted."
  type        = string
  default     = null
}

variable "image_repository" {
  description = "Image repository where the XRd container image is hosted."
  type        = string
  default     = "xrd-test/xrd-vrouter"
}

variable "image_tag" {
  description = "Tag of the XRd container image in the repository."
  type        = string
  nullable    = false
  default     = "latest"
}
