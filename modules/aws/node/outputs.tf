output "hugepages_gb" {
  description = "The number of 1GiB hugepages allocated (null if not using an XRd Packer AMI)"
  value       = local.hugepages_gb
}

output "id" {
  description = "ID of the node"
  value       = aws_instance.this.id
}

output "isolated_cores" {
  description = "The CPUs marked as isolated (null if not using an XRd Packer AMI)"
  value       = local.isolated_cores
}

output "private_ip" {
  description = "Primary private IPv4 address of the node"
  value       = aws_instance.this.private_ip
}
