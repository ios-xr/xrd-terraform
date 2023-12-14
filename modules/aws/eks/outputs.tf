output "id" {
  description = "Cluster ID"
  value       = aws_eks_cluster.this.id
}

output "name" {
  description = "Cluster name"
  value       = aws_eks_cluster.this.name
}

output "oidc_issuer" {
  description = "OIDC issuer URL for the cluster"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}
