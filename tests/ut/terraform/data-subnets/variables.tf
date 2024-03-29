variable "aws_endpoint" {
  description = "AWS endpoint URL"
  type        = string
  nullable    = false
}

variable "availability_zone" {
  description = "AZ in which to create the security group and all subnets"
  type        = string
  nullable    = false
}

variable "name_prefix" {
  description = "Used as a prefix for the 'Name' tag for each created resource"
  type        = string
  nullable    = false
}

variable "subnet_count" {
  description = "Number of subnets to create"
  type        = number
  nullable    = false
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  nullable    = false
}
