variable "image_registry" {
  description = "Image registry where the XRd container image is hosted"
  type        = string
  default     = null
}

variable "image_repository" {
  description = "Image repository where the XRd container image is hosted"
  type        = string
  default     = "xrd/xrd-vrouter"
}

variable "image_tag" {
  description = "Tag of the XRd container image in the repository"
  type        = string
  nullable    = false
  default     = "latest"
}
