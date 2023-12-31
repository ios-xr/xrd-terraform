output "id" {
  description = "ID of the node"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Primary private IPv4 address of the node"
  value       = aws_instance.this.private_ip
}

output "interface_ip_addresses" {
  description = "List of lists of private IPv4 addresses for the interfaces attached to the node."
  value = [
    for ni in aws_network_interface.this :
    ni.private_ip_list
  ]
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
  value       = local.instance_type_to_xrd_cpuset[var.instance_type]
}

output "network_interface" {
  value = aws_network_interface.this
}

output "ready" {
  value = var.wait ? time_sleep.wait[0].id : 1
}
