resource "kubernetes_manifest" "this" {
  for_each = toset(compact(split(
    "---",
    templatefile(
      "${path.module}/templates/linux-pod-with-net-attach.yaml.tftpl",
      {
        name          = var.name
        namespace     = "default"
        device        = var.device
        ip_address    = var.ip_address
        gateway       = var.gateway
        routes        = var.routes
        node_selector = var.node_selector
      }
    )
  )))

  manifest = yamldecode(each.key)
}
