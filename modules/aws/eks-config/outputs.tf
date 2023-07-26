output "cluster_name" {
  description = "EKS cluster name"
  value       = var.cluster_name
}

output "oidc_provider" {
  description = "OIDC provider ARN for the cluster"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_issuer" {
  description = "OIDC issuer URL for the cluster"
  value       = var.oidc_issuer
}

output "node_iam_instance_profile_name" {
  description = "Name of the IAM instance profile to be used for worker nodes"
  value       = aws_iam_instance_profile.node.name
}
