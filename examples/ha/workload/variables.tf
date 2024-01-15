variable "ha_app_chart_name" {
  description = <<-EOT
  HA app Helm chart name.
  This can be a local path, a URL, or the name of the chart if 'ha_app_chart_repository' is specified.
  EOT
  type        = string
  nullable    = false
}

variable "ha_app_chart_repository" {
  description = <<-EOT
  HA app Helm chart repository URL.
  This may be set to null, in which case 'ha_app_chart_name' must be set to a local path or a URL.
  EOT
  type        = string
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

variable "xr_root_password" {
  description = "Root user password to use on XRd instances."
  type        = string
  nullable    = false
}

variable "xr_root_user" {
  description = "Root user name to use on XRd instances."
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
