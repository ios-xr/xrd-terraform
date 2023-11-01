variable "endpoint" {
  type = string
}

variable "ami" {
  type = string
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
    subnet_id : string
    private_ip_address : string
    security_groups : list(string)
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

variable "xrd_ami_data" {
  type = object({
    hugepages_gb : number
    isolated_cores : string
  })
  default = null
}
