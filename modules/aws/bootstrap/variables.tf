variable "azs" {
  description = <<-EOT
  List of exactly two availability zones.
  A public and a private subnet is created in each availablity zone.
  An EKS cluster is created in the two private subnets.
  EOT
  type = list(string)
  nullable = false
}

variable "cluster_version" {
  description = "Cluster version"
  type    = string
  nullable = false
}

variable "name" {
  description = "Used as a prefix for the 'Name' tag for each created resource"
  type     = string
  nullable = false
}
