output "cluster_name" {
  description = "Cluster name"
  value       = local.bootstrap.cluster_name
}

output "cnf_rtb_id" {
  description = "ID of the route table used to demonstrate the 'aws_update_route_table' action"
  value       = aws_route_table.cnf_vrid2.id
}

output "ha_app_role_arn" {
  description = "IAM role that the HA app service account should assume"
  value       = module.ha_app_irsa.role_arn
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file"
  value       = local.bootstrap.kubeconfig_path
}

output "nodes" {
  description = "Map of worker node name to instance ID"
  value       = { for name in keys(local.nodes) : name => module.node[name].id }
}

output "vpc_endpoint_id" {
  description = "VPC endpoint ID"
  value       = aws_vpc_endpoint.ec2.id
}
