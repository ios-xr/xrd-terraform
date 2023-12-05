variable "availability_zone" {
  description = "AZ in which to create the security group and all subnets"
  type        = string
  nullable    = false
}

variable "count" {
  description = "Number of subnets to create"
  type        = int
  nullable    = false
}

variable "name_prefix" {
  description = "Used as a prefix for the 'Name' tag for each created resource"
  type        = string
  nullable    = false
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  nullable    = false
}
