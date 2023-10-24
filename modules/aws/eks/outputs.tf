output "name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "endpoint" {
  description = "Endpoint URL for the cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "ca_cert" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = local.ca_cert
}

output "oidc_issuer" {
  description = "OIDC issuer URL for the cluster"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
