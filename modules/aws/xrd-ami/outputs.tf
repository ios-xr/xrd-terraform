output "id" {
  description = "ID of the most-recent XRd-compatible AMI meeting the restrictions"
  value       = data.aws_ami.this.id
}
