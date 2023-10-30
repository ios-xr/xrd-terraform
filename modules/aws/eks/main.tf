data "aws_iam_policy_document" "cluster" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  assume_role_policy = data.aws_iam_policy_document.cluster.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
  ]
  name = "${var.name}-cluster"
}

resource "null_resource" "cluster_version" {
  triggers = {
    cluster_version = var.cluster_version
  }
}

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  vpc_config {
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = var.security_group_ids
    subnet_ids              = var.subnet_ids
  }
  version = var.cluster_version

  # It is not possible to downgrade the EKS cluster version; instead
  # unconditionally replace the resource when the cluster version changes.
  lifecycle {
    replace_triggered_by = [null_resource.cluster_version]
  }
}

resource "null_resource" "kubeconfig" {
  count = var.kubeconfig_output_path != null ? 1 : 0

  triggers = {
    id = aws_eks_cluster.this.id
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${var.name} --kubeconfig ${var.kubeconfig_output_path}"
  }
}

locals {
  ca_cert = aws_eks_cluster.this.certificate_authority[0].data
}
