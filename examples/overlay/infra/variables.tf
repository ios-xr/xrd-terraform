variable "node_instance_type" {
  type    = string
  default = "m5.2xlarge"
}

variable "node_ami" {
  type    = string
  default = null
}

variable "placement_group" {
  type    = string
  default = null
}
