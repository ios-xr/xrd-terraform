variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  nullable    = false
  default     = "xrd-cluster"
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
  default     = "xrd/xrd-vrouter"
}

variable "image_tag" {
  description = "Tag of the XRd container image in the repository."
  type        = string
  nullable    = false
  default     = "latest"
}
