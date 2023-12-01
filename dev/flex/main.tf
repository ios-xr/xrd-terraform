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

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

locals {
  node_names = [for i in range(var.node_count) :
    try(var.node_names[i], format("node%d", i + 1))
  ]

  name_prefix = local.bootstrap.name_prefix
}

resource "aws_subnet" "data" {
  count = var.interface_count

  availability_zone = data.aws_subnet.cluster.availability_zone
  cidr_block        = "10.0.${count.index + 10}.0/24"
  vpc_id            = local.bootstrap.vpc_id
}

resource "aws_security_group" "data" {
  name   = "${local.name_prefix}-data"
  vpc_id = local.bootstrap.vpc_id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = -1
    self      = true
  }
}

module "eks_config" {
  source = "../../modules/aws/eks-config"

  cluster_name      = local.bootstrap.cluster_name
  name_prefix       = local.name_prefix
  node_iam_role_arn = data.aws_iam_role.node.arn
  oidc_issuer       = local.bootstrap.oidc_issuer
  oidc_provider     = local.bootstrap.oidc_provider
}

module "xrd_ami" {
  source = "../../modules/aws/xrd-ami"
  count  = var.node_ami == null ? 1 : 0

  cluster_version = data.aws_eks_cluster.this.version
}

locals {
  # Use this data source so it's evaluated.
  instance_type = data.aws_ec2_instance_type.current.instance_type

  nodes = {
    for i in range(var.node_count) :
    try(var.node_names[i], "node${i}") => {
      private_ip_address = cidrhost(data.aws_subnet.cluster.cidr_block, i + 11)
      network_interfaces = [
        for j in range(var.interface_count) :
        {
          private_ips     = [cidrhost(aws_subnet.data[j].cidr_block, i + 11)]
          security_groups = [aws_security_group.data.id]
          subnet_id       = aws_subnet.data[j].id
        }
      ]
    }
  }
}

module "node" {
  source   = "../../modules/aws/node"
  for_each = local.nodes

  name                 = "${local.name_prefix}-${each.key}"
  ami                  = var.node_ami != null ? var.node_ami : module.xrd_ami[0].id
  cluster_name         = local.bootstrap.cluster_name
  iam_instance_profile = local.bootstrap.node_iam_instance_profile_name
  instance_type        = var.node_instance_type
  key_name             = local.bootstrap.key_pair_name
  network_interfaces   = each.value.network_interfaces
  private_ip_address   = each.value.private_ip_address
  security_groups = [
    local.bootstrap.bastion_security_group_id,
    data.aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
  ]
  subnet_id = data.aws_subnet.cluster.id

  labels = {
    name = each.key
  }
}

locals {
  vrouter = var.xrd_platform == "vRouter"

  default_repo_names = {
    "vRouter" : "xrd/xrd-vrouter"
    "ControlPlane" : "xrd/xrd-control-plane"
  }
  default_image_repository = format(
    "%s.dkr.ecr.%s.amazonaws.com/%s",
    data.aws_caller_identity.current.account_id,
    data.aws_region.current.name,
    local.default_repo_names[var.xrd_platform]
  )
  image_repository = coalesce(var.image_repository, local.default_image_repository)

  chart_names = {
    "vRouter" : "xrd-vrouter"
    "ControlPlane" : "xrd-control-plane"
  }
  chart_name = local.chart_names[var.xrd_platform]

  values_template_file = local.vrouter ? "${path.module}/templates/values-vrouter.yaml.tftpl" : "${path.module}/templates/values-control-plane.yaml.tftpl"

  cpuset = (
    contains(["m5.24xlarge", "m5n.24xlarge"], var.node_instance_type) ?
    "12-23" :
    "2-3"
  )
}

resource "local_file" "chart_yaml" {
  count = var.create_helm_chart ? 1 : 0

  content = templatefile(
    "${path.module}/templates/Chart.yaml.tftpl",
    {
      xrd_chart            = local.chart_name
      xrd_chart_version    = "~1.0.0-0"
      xrd_chart_repository = "https://ios-xr.github.io/xrd-helm"
      nodes                = local.nodes
    }
  )

  filename = "${path.root}/xrd-flex/Chart.yaml"
}

resource "local_file" "chart_values_yaml" {
  count = var.create_helm_chart ? 1 : 0

  content = templatefile(
    local.values_template_file,
    {
      image_repository = local.image_repository
      image_tag        = var.image_tag
      xr_root_user     = var.xr_root_user
      xr_root_password = var.xr_root_password
      nodes            = local.nodes
      ifname_stem      = local.vrouter ? "HundredGigE" : "GigabitEthernet"
      cpusets          = { for name, out in module.node : name => local.cpuset }
      hugepages        = { for name, out in module.node : name => out.hugepages_gb }
    }
  )

  filename = "${path.root}/xrd-flex/values.yaml"

  depends_on = [local_file.chart_yaml]

  provisioner "local-exec" {
    command     = "helm dependency update"
    working_dir = "${path.root}/xrd-flex"
  }
}
