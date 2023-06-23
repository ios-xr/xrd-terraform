output "name" {
  description = "EKS cluster name"
  value       = var.name
}

output "endpoint" {
  description = "Endpoint URL for the cluster"
  value       = aws_eks_cluster.this.endpoint
}

output "ca_cert" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = local.ca_cert
}

output "oidc_provider" {
  description = "OIDC provider ARN for the cluster"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_issuer" {
  description = "OIDC issuer URL for the cluster"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_iam_instance_profile_name" {
  description = "Name of the IAM instance profile to be used for worker nodes"
  value       = aws_iam_instance_profile.node.name
}
