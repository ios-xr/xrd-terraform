variable "key_name" {
  description = "Name of the key pair to be generated"
  type        = string
  nullable    = false
}

variable "download" {
  description = "Whether to download the key to the local machine after creation"
  type        = bool
  nullable    = false
  default     = false
}
