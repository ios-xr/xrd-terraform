variable "name" {
  type = string
}

variable "device" {
  type = string
}

variable "ip_address" {
  type = string
}

variable "gateway" {
  type = string
}

variable "routes" {
  type = list(string)
}

variable "node_selector" {
  type = map(string)
  default = null
}
