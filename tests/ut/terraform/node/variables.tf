variable "aws_endpoint" {
  type = string
}

variable "ami" {
  type = string
}

variable "is_xrd_ami" {
  type = bool
}

variable "cluster_name" {
  type = string
}

variable "iam_instance_profile" {
  type = string
}

variable "key_name" {
  type = string
}

variable "name" {
  type = string
}

variable "private_ip_address" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "m5.2xlarge"
}

variable "kubelet_extra_args" {
  type    = string
  default = ""
}

variable "network_interfaces" {
  type = list(object({
    private_ips : list(string)
    security_groups : list(string)
    subnet_id : string
  }))
  default = []
}

variable "security_groups" {
  type    = list(string)
  default = []
}

variable "user_data" {
  type    = string
  default = ""
}
