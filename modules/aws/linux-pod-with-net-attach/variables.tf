variable "name" {
  description = "Name of the Pod"
  type        = string
  nullable    = false
}

variable "device" {
  description = "Name of the device to move from the host network namespace to the container network namespace"
  type        = string
  nullable    = false
}

variable "ip_address" {
  description = "IP address to assign to the device"
  type        = string
  nullable    = false
}

variable "gateway" {
  description = "Gateway address"
  type        = string
  nullable    = false
}

variable "routes" {
  description = "List of routes to add to the container network namespace"
  type        = list(string)
  nullable    = false
}

variable "node_selector" {
  description = "Map of labels to values to use as the Pod node selector"
  type        = map(string)
  default     = null
}
