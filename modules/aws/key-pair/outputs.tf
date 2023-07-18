output "key_name" {
  description = "Name of the generated key pair"
  value       = aws_key_pair.this.key_name
}
