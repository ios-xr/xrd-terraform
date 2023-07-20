terraform {
  required_version = ">= 1.2.0"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

data "kubectl_file_documents" "this" {
  content = templatefile(
    "${path.module}/templates/simple-host.yaml.tftpl",
    {
      name          = var.name
      device        = var.device
      ip_address    = var.ip_address
      gateway       = var.gateway
      routes        = var.routes
      node_selector = var.node_selector
    }
  )
}

resource "kubectl_manifest" "this" {
  for_each = {
    deploy         = data.kubectl_file_documents.this.manifests["/apis/apps/v1/deployments/${var.name}"]
    net_attach_def = data.kubectl_file_documents.this.manifests["/apis/k8s.cni.cncf.io/v1/networkattachmentdefinitions/${var.name}"]
  }

  yaml_body        = each.value
  wait_for_rollout = false
}

output "docs" {
  value = data.kubectl_file_documents.this
}
