variable "instance_type" {
  description = "Instance type"
  type        = string
  nullable    = false

  validation {
    condition = contains(
      ["m5.2xlarge", "m5n.2xlarge", "m5.24xlarge", "m5n.24xlarge"],
      var.instance_type,
    )
    error_message = "Must be one of: 'm5.2xlarge', 'm5n.2xlarge', 'm5.24xlarge', 'm5n.24xlarge'."
  }
}

variable "use_case" {
  description = "XRd use case"
  type        = string
  nullable    = false

  validation {
    condition     = contains(["cloud-router", "lab", "sr-pce"], var.use_case)
    error_message = "Must be one of: 'cloud-router', 'lab', 'sr-pce'."
  }
}
