variable "azs" {
  description = <<-EOT
  List of exactly two availability zones.
  A public and a private subnet is created in each availability zone.
  An EKS cluster is created in the two private subnets.
  EOT
  type        = list(string)
  nullable    = false
}

variable "bastion_remote_access_cidr_blocks" {
  description = "Allowed CIDR blocks for external SSH access to the Bastion instance"
  type        = list(string)
  default     = null
}

variable "cluster_version" {
  description = "Cluster version"
  type        = string
  nullable    = false
}

variable "kubeconfig_path" {
  description = <<-EOT
  Write kubectl configuration to this file.
  If null, '.kubeconfig' relative to Terraform's working directory is used.
  EOT
  type        = string
  default     = null
}

variable "name_prefix" {
  description = <<-EOT
  Used as a prefix for the 'Name' tag for each created resource.
  If null, then a random name 'xrd-terraform-[0-9a-z]{8}' is used.
  EOT
  type        = string
  default     = null
}
