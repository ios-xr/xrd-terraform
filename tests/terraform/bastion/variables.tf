variable "endpoint" {
  type = string
}

variable "ami" {
  type     = string
  nullable = false
}

variable "key_name" {
  type     = string
  nullable = false
}

variable "subnet_id" {
  type     = string
  nullable = false
}

variable "instance_type" {
  type    = string
  default = null
}

variable "remote_access_cidr" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "security_group_ids" {
  type    = list(string)
  default = null
}
