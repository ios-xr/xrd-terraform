variable "name" {
  description = <<-EOT
  Used as a prefix for the 'Name' tag for each created resource".
  If null, then a random name 'xrd-terraform-[0-9a-z]{8}' is used.
  EOF
  type     = string
  default = null
}

variable "cluster_version" {
  description = "Cluster version"
  type    = string
  default = "1.28"
  nullable = false
}
