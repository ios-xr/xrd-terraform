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
