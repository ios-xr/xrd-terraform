variable "instance_type" {
  description = "Instance type"
  type        = string
  nullable    = false
}

variable "use_case" {
  description = "XRd use case"
  type        = string
  nullable    = false

  validation {
    condition     = contains(["cloud-router", "minimal", "maximal"], var.use_case)
    error_message = "Must be one of: 'cloud-router', 'minimal', 'maximal'."
  }
}
