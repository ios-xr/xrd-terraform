data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "${path.root}/../infra/terraform.tfstate"
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

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
  vrouter = var.xrd_platform == "vRouter"

  default_repo_names = {
    "vRouter" : "xrd/xrd-vrouter"
    "ControlPlane" : "xrd/xrd-control-plane"
  }

  image_repository = format(
    "%s/%s",
    coalesce(
      var.image_registry,
      format(
        "%s.dkr.ecr.%s.amazonaws.com",
        data.aws_caller_identity.current.account_id,
        data.aws_region.current.name,
      ),
    ),
    coalesce(var.image_repository, local.default_repo_names[var.xrd_platform]),
  )
}

resource "helm_release" "xrd" {
  name       = "xrd"
  repository = "https://ios-xr.github.io/xrd-helm"
  chart      = local.vrouter ? "xrd-vrouter" : "xrd-control-plane"

  values = [
    templatefile(
      local.vrouter ? "${path.module}/templates/xrd-vr.yaml.tftpl" : "${path.module}/templates/xrd-cp.yaml.tftpl",
      {
        image_repository         = local.image_repository
        image_tag                = var.image_tag
        xr_root_user             = var.xr_root_user
        xr_root_password         = var.xr_root_password
        loopback_ip              = "1.1.1.1"
        interface_count          = 3
        interface_ipv4_addresses = ["10.0.10.10", "10.0.11.10", "10.0.12.10"]
        cpuset                   = "2-3" #@@@
      }
    )
  ]
}
