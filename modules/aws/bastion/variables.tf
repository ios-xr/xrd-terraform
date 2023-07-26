variable "subnet_id" {
  description = "Subnet ID to deploy the bastion node into"
  type        = string
  nullable = false
}

variable "instance_type" {
  description = "EC2 instance type for the bastion node"
  type        = string
  default     = "t3.nano"
  nullable = false
}

variable "key_name" {
  description = "Name of an existing EC2 key pair to install onto the bastion node"
  type        = string
  nullable = false
}

variable "ami" {
  description = "AMI to use for the bastion. Default is to use the latest Amazon Linux 2023 AMI"
  type        = string
  default     = null
}

variable "security_group_ids" {
  description = "Additional security group IDs to add to the primary interface on the bastion node"
  type        = list(string)
  default     = null
}

variable "remote_access_cidr" {
  description = "Allowed CIDR blocks for external SSH access to the bastion. Default is unrestricted (0.0.0.0/0)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
  nullable = false
}
