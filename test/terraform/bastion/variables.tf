variable "endpoint" {
  type = string
}

variable "subnet_id" {
  type     = string
  nullable = false
}

variable "instance_type" {
  type    = string
  default = null
}

variable "key_name" {
  type     = string
  nullable = false
}

variable "ami" {
  type    = string
  default = null
}

variable "security_group_ids" {
  type    = list(string)
  default = null
}

variable "remote_access_cidr" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
