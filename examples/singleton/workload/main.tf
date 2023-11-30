provider "helm" {
  repository_config_path = "${path.root}/.helm/repositories.yaml"
  repository_cache       = "${path.root}/.helm"
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

locals {
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
    coalesce(var.image_repository, "xrd/${var.xrd_platform}"),
  )
}

resource "helm_release" "xrd" {
  name       = "xrd"
  repository = "https://ios-xr.github.io/xrd-helm"
  chart      = var.xrd_platform

  values = [
    templatefile(
      "${path.module}/templates/${var.xrd_platform}.yaml.tftpl",
      {
        image_repository         = local.image_repository
        image_tag                = var.image_tag
        xr_root_user             = var.xr_root_user
        xr_root_password         = var.xr_root_password
        loopback_ip              = "1.1.1.1"
        interface_count          = 3
        interface_ipv4_addresses = ["10.0.10.10", "10.0.11.10", "10.0.12.10"]
        cpuset = (
          contains(["m5.24xlarge", "m5n.24xlarge"], data.aws_instance.node.instance_type) ?
          "12-23" :
          "2-3"
        )
      }
    )
  ]
}
