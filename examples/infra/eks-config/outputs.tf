output "cluster_name" {
  description = "EKS cluster name"
  value       = var.cluster_name
}

output "oidc_issuer" {
  description = "OIDC issuer URL for the cluster"
  value       = var.oidc_issuer
}

output "oidc_provider" {
  description = "OIDC provider ARN for the cluster"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "node_iam_instance_profile_name" {
  description = "Name of the IAM instance profile to be used for worker nodes"
  value       = module.eks_config.aws_iam_instance_profile.node.name
}

output "key_name" {
  description = "Key pair name"
  value       = module.key_pair.key_name
}

output "bastion_id" {
  description = "ID of the bastion EC2 instance"
  value       = module.bastion.id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion"
  value       = module.bastion.public_ip
}
