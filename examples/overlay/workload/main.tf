terraform {
  required_version = ">= 1.2.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.18"
    }
  }
}

provider "helm" {
  repository_config_path = "${path.root}/.helm/repositories.yaml"
  repository_cache       = "${path.root}/.helm"
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
      command     = "aws"
    }
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
  load_config_file = false
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

module "eks_config" {
  source = "../../../modules/aws/eks-config"

  cluster_name      = var.cluster_name
  oidc_issuer       = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  oidc_provider     = data.terraform_remote_state.infra.outputs.oidc_provider
  node_iam_role_arn = data.aws_iam_role.node.arn
}


locals {
  image_repository = coalesce(
    var.image_repository,
    format(
      "%s.dkr.ecr.%s.amazonaws.com/xrd/xrd-vrouter",
      data.aws_caller_identity.current.account_id,
      data.aws_region.current.name,
    ),
  )
}

resource "helm_release" "xrd1" {
  name       = "xrd1"
  repository = "https://ios-xr.github.io/xrd-helm"
  chart      = "xrd-vrouter"

  values = [
    templatefile(
      "${path.module}/templates/xrd1.yaml.tftpl",
      {
        xr_root_user     = var.xr_root_user,
        xr_root_password = var.xr_root_password
        image_repository = local.image_repository
        image_tag        = var.image_tag
        cpuset           = "2-3"
      }
    )
  ]
}

resource "helm_release" "xrd2" {
  name       = "xrd2"
  repository = "https://ios-xr.github.io/xrd-helm"
  chart      = "xrd-vrouter"

  values = [
    templatefile(
      "${path.module}/templates/xrd2.yaml.tftpl",
      {
        xr_root_user     = var.xr_root_user,
        xr_root_password = var.xr_root_password
        image_repository = local.image_repository
        image_tag        = var.image_tag
        cpuset           = "2-3"
      }
    )
  ]
}

module "cnf" {
  source = "../../../modules/aws/linux-pod-with-net-attach"

  name       = "cnf"
  device     = "eth1"
  ip_address = "10.0.10.10/24"
  gateway    = "10.0.10.11"
  routes     = ["10.0.13.0/24"]
  node_selector = {
    name = "gamma"
  }
}

module "peer" {
  source = "../../../modules/aws/linux-pod-with-net-attach"

  name       = "peer"
  device     = "eth2"
  ip_address = "10.0.13.10/24"
  gateway    = "10.0.13.12"
  routes     = ["10.0.10.0/24"]
  node_selector = {
    name = "gamma"
  }
}
