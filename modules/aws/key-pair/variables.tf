variable "key_name" {
  description = "Name of the key pair to be generated"
  type        = string
  nullable    = false
}

output "filename" {
  description = "Path to the file that the key pair is written to"
  value       = var.filename ? local_sensitive_file.this.filename : null
  default     = null
}
