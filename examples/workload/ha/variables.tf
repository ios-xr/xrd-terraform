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

variable "xrd_image_registry" {
  description = "Image registry where the XRd container image is hosted."
  type        = string
  default     = null
}

variable "xrd_image_repository" {
  description = "Image repository where the XRd container image is hosted."
  type        = string
  default     = "xrd/xrd-vrouter"
}

variable "xrd_image_tag" {
  description = "Tag of the XRd container image in the repository."
  type        = string
  nullable    = false
  default     = "latest"
}

variable "ha_app_image_registry" {
  description = "Image registry where the HA app container image is hosted."
  type        = string
  default     = null
}

variable "ha_app_image_repository" {
  description = "Image repository where the HA app container image is hosted."
  type        = string
  default     = "xrd/xrd-ha-app"
}

variable "ha_app_image_tag" {
  description = "Tag of the HA app container image in the repository."
  type        = string
  nullable    = false
  default     = "latest"
}

variable "ha_app_chart_repository" {
  description = <<-EOT
  HA app Helm chart repository URL.
  This may be set to null, in which case 'ha_app_chart_name' must be set to a local path or a URL.
  EOT
  type        = string
}

variable "ha_app_chart_name" {
  description = <<-EOT
  HA app Helm chart name.
  This can be a local path, a URL, or the name of the chart if 'ha_app_chart_repository' is specified.
  EOT
  type        = string
  nullable    = false
}
