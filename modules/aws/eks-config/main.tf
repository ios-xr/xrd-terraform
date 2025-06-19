resource "kubernetes_config_map" "aws_auth" {
  data = {
    "mapRoles" = <<-EOT
      - rolearn: ${var.node_iam_role_arn}
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

module "ebs_csi_irsa" {
  source = "../irsa"

  oidc_issuer     = var.oidc_issuer
  oidc_provider   = var.oidc_provider
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_name       = "${var.name_prefix}-ebs-csi"
  role_policies   = [data.aws_iam_policy.ebs_csi_driver_policy.arn]
}

resource "helm_release" "ebs_csi" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  set = [{
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.ebs_csi_irsa.role_arn
  }]
  wait = false
}

resource "kubernetes_manifest" "multus" {
  for_each = toset(compact(split("---", data.http.multus_yaml.response_body)))

  manifest = yamldecode(each.key)
}
