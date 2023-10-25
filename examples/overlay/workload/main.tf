provider "helm" {
  repository_config_path = "${path.root}/.helm/repositories.yaml"
  repository_cache       = "${path.root}/.helm"
  kubernetes {
    config_path = data.terraform_remote_state.infra.outputs.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = data.terraform_remote_state.infra.outputs.kubeconfig_path
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