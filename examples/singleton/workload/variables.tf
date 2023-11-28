variable "image_registry" {
  description = "Image registry where the XRd container image is hosted"
  type        = string
  default     = null
}

variable "image_repository" {
  description = "Image repository where the XRd container image is hosted"
  type        = string
  default     = null
}

variable "image_tag" {
  description = "Tag of the XRd container image in the repository"
  type        = string
  nullable    = false
  default     = "latest"
}

variable "xr_root_user" {
  description = "Root user name to use on XRd instances"
  type        = string
  nullable    = false
}

variable "xr_root_password" {
  description = "Root user password to use on XRd instances"
  type        = string
  nullable    = false
}

variable "xrd_platform" {
  description = "Which XRd platform to launch"
  type        = string
  default     = "xrd-vrouter"
  nullable    = false

  validation {
    condition     = contains(["xrd-control-plane", "xrd-vrouter"], var.xrd_platform)
    error_message = "Allowed values are \"xrd-control-plane\" or \"xrd-vrouter\""
  }
}
