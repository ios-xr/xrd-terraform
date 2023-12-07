variable "aws_endpoint" {
  description = "AWS endpoint URL"
  type        = string
  nullable    = false
}

variable "key_name" {
  description = "Name of the key pair to be generated"
  type        = string
  nullable    = false
}

variable "filename" {
  description = "Path to the file that the key pair is written to"
  type        = string
  nullable    = false
}
