variable "availability_zone" {
  description = "AZ in which to create the security group and all subnets"
  type        = string
  nullable    = false
}

variable "cidr_blocks" {
  description = "List of subnet CIDR blocks"
  type        = list(string)
  nullable    = false
}

variable "security_group_name" {
  description = "Security group name"
  type        = string
  nullable    = false
}

variable "names" {
  description = "Subnet names"
  type        = list(string)
  nullable    = false
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  nullable    = false
}
