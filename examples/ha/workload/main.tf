provider "helm" {
  repository_config_path = "${path.root}/.helm/repositories.yaml"
  repository_cache       = "${path.root}/.helm"
  kubernetes {
    config_path = local.infra.kubeconfig_path
  }
}

provider "kubernetes" {
  config_path = local.infra.kubeconfig_path
}

locals {
  default_image_registry = format(
    "%s.dkr.ecr.%s.amazonaws.com",
    data.aws_caller_identity.current.account_id,
    data.aws_region.current.name,
  )

  xrd_image = format(
    "%s/%s",
    coalesce(var.xrd_image_registry, local.default_image_registry),
    var.xrd_image_repository,
  )

  ha_app_image = format(
    "%s/%s",
    coalesce(var.ha_app_image_registry, local.default_image_registry),
    var.ha_app_image_repository,
  )
}

module "node_props" {
  source = "../../../modules/aws/node-props"

  for_each = data.aws_instance.nodes

  instance_type = each.value.instance_type
  use_case      = "maximal"
}

resource "helm_release" "xrd1" {
  name       = "xrd1"
  repository = var.ha_app_chart_repository
  chart      = var.ha_app_chart_name

  values = [
    templatefile(
      "${path.module}/templates/xrd1.yaml.tftpl",
      {
        cpuset               = module.node_props["alpha"].cpuset
        xr_root_password     = var.xr_root_password
        xr_root_user         = var.xr_root_user
        xrd_image_repository = local.xrd_image
        xrd_image_tag        = var.xrd_image_tag

        ec2_endpoint_url         = data.aws_vpc_endpoint.ec2.dns_entry[0].dns_name
        ha_app_image_repository  = local.ha_app_image
        ha_app_image_tag         = var.ha_app_image_tag
        ha_app_role_arn          = local.infra.ha_app_role_arn
        route_table_id           = local.infra.cnf_rtb_id
        target_network_interface = data.aws_network_interface.target["alpha"].id
      }
    )
  ]
}

resource "helm_release" "xrd2" {
  name       = "xrd2"
  repository = var.ha_app_chart_repository
  chart      = var.ha_app_chart_name

  values = [
    templatefile(
      "${path.module}/templates/xrd2.yaml.tftpl",
      {
        cpuset               = module.node_props["beta"].cpuset
        xr_root_password     = var.xr_root_password
        xr_root_user         = var.xr_root_user
        xrd_image_repository = local.xrd_image
        xrd_image_tag        = var.xrd_image_tag

        ec2_endpoint_url         = data.aws_vpc_endpoint.ec2.dns_entry[0].dns_name
        ha_app_image_repository  = local.ha_app_image
        ha_app_image_tag         = var.ha_app_image_tag
        ha_app_role_arn          = local.infra.ha_app_role_arn
        route_table_id           = local.infra.cnf_rtb_id
        target_network_interface = data.aws_network_interface.target["beta"].id
      }
    )
  ]
}

module "peer" {
  source = "../../../modules/aws/linux-pod-with-net-attach"

  name       = "peer"
  device     = "eth1"
  ip_address = "10.0.10.12/24"
  gateway    = "10.0.10.20"
  routes     = ["10.0.11.0/24", "10.0.13.0/24"]
  node_selector = {
    name = "gamma"
  }
}

module "cnf_vrid1" {
  source = "../../../modules/aws/linux-pod-with-net-attach"

  name       = "cnf-vrid1"
  device     = "eth2"
  ip_address = "10.0.11.12/24"
  gateway    = "10.0.11.20"
  routes     = ["10.0.10.0/24"]
  node_selector = {
    name = "gamma"
  }
}

module "cnf_vrid2" {
  source = "../../../modules/aws/linux-pod-with-net-attach"

  name       = "cnf-vrid2"
  device     = "eth3"
  ip_address = "10.0.13.12/24"
  gateway    = "10.0.13.1"
  routes     = ["10.0.10.0/24"]
  node_selector = {
    name = "gamma"
  }
}
