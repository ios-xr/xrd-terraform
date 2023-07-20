output "key_name" {
  description = "Name of the generated key pair"
  value       = aws_key_pair.this.key_name
}

output "filename" {
  description = "Path to the key pair file"
  value       = var.filename ? local_sensitive_file.this[0].filename : null
}
