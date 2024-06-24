variable "aws_endpoint" {
  description = "AWS endpoint URL"
  type        = string
  nullable    = false
}

variable "ami" {
  description = <<-EOT
  AMI to use for the Bastion instance.
  If null, the latest Amazon Linux 2023 AMI is used.
  EOT
  type        = string
  default     = null
}

variable "instance_type" {
  description = "Instance type to use for the Bastion instance"
  type        = string
  default     = "t3.nano"
  nullable    = false
}

variable "key_name" {
  description = "Name of an existing key pair to assign to the Bastion instance"
  type        = string
  nullable    = false
}

variable "name" {
  description = "Name of the Bastion instance"
  type        = string
  nullable    = false
}

variable "remote_access_cidr" {
  description = "Allowed CIDR blocks for external SSH access to the Bastion instance"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "security_group_ids" {
  description = "Additional security group IDs to add to the primary interface"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "subnet_id" {
  description = "Subnet ID to launch the Bastion instance in"
  type        = string
  nullable    = false
}
