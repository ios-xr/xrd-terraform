output "id" {
  description = "ID of the node"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Primary private IPv4 address of the node"
  value       = aws_instance.this.private_ip
}

output "isolated_cores" {
  description = "The cpuset marked as isolated (null if not using an xrd-packer AMI)"
  value       = local.isolated_cores
}

output "hugepages_gb" {
  description = "The number of 1GiB hugepages allocated (null if not using an xrd-packer AMI)"
  value       = local.hugepages_gb
}

output "xrd_cpuset" {
  description = "The cpuset XRd vRouter should be configured with on the given node instance type"
  value       = local.xrd_cpuset
}

output "network_interface" {
  value = aws_network_interface.this
}
