variable "endpoint" {
  type = string
}

variable "name" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "endpoint_public_access" {
  type    = bool
  default = null
}

variable "endpoint_private_access" {
  type    = bool
  default = null
}

variable "public_access_cidrs" {
  type    = list(string)
  default = null
}

variable "subnet_ids" {
  type = list(string)
}
