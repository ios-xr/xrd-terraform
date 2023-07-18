terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.3"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.18"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}

data "aws_region" "current" {}

data "aws_iam_policy_document" "node" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  assume_role_policy = data.aws_iam_policy_document.node.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
  ]
  name = "${var.cluster_name}-${data.aws_region.current.name}-node"
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.cluster_name}-${data.aws_region.current.name}-node"
  role = aws_iam_role.node.name
}


data "tls_certificate" "this" {
  url = var.oidc_issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.this.certificates[*].sha1_fingerprint
  url             = data.tls_certificate.this.url
}

resource "kubernetes_config_map" "aws_auth" {
  data = {
    "mapRoles" = <<-EOT
      - rolearn: ${aws_iam_role.node.arn}
        username: system:node:{{EC2PrivateDNSName}}
        groups:
          - system:bootstrappers
          - system:nodes
    EOT
  }

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
}

resource "kubernetes_env" "max_eni" {
  api_version = "apps/v1"
  kind        = "DaemonSet"
  container   = "aws-node"

  metadata {
    name      = "aws-node"
    namespace = "kube-system"
  }

  env {
    name  = "MAX_ENI"
    value = 1
  }
}

data "aws_iam_policy" "ebs_csi_driver_policy" {
  name = "AmazonEBSCSIDriverPolicy"
}

module "ebs_csi_irsa" {
  source = "../irsa"

  oidc_issuer     = var.oidc_issuer
  oidc_provider   = aws_iam_openid_connect_provider.this.arn
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_name       = "${var.cluster_name}-${data.aws_region.current.name}-ebs-csi"
  role_policies   = [data.aws_iam_policy.ebs_csi_driver_policy.arn]
}

resource "helm_release" "ebs_csi" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.ebs_csi_irsa.role_arn
  }
  wait = var.wait
}

data "http" "multus_yaml" {
  url = "https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/master/config/multus/v3.7.2-eksbuild.1/aws-k8s-multus.yaml"
}

data "kubectl_file_documents" "multus" {
  content = data.http.multus_yaml.response_body
}

resource "kubectl_manifest" "multus" {
  for_each = data.kubectl_file_documents.multus.manifests

  yaml_body = each.value
}
