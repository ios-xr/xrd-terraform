output "node_ids" {
  description = "IDs of the worker nodes (if created)"
  value       = [for _, node in module.node : node.id]
}

output "interface_ipv4_addresses" {
  description = "List of lists of primary private IPv4 addresses for the interfaces attached to each worker node."
  value = [
    for _, node_info in local.nodes :
    node_info.network_interfaces[*].private_ips[0]
  ]
}
