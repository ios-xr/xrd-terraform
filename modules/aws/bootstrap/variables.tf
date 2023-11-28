variable "azs" {
  description = <<-EOT
  List of exactly two availability zones.
  A public and a private subnet is created in each availability zone.
  An EKS cluster is created in the two private subnets.
  EOT
  type        = list(string)
  nullable    = false
}

variable "cluster_version" {
  description = "Cluster version"
  type        = string
  nullable    = false
}

variable "name_prefix" {
  description = <<-EOT
  Used as a prefix for the 'Name' tag for each created resource.
  If null, then a random name 'xrd-terraform-[0-9a-z]{8}' is used.
  EOT
  type        = string
  default     = null
}
