variable "name_prefix" {
  description = <<-EOT
  Used as a prefix for the 'Name' tag for each created resource.
  If null, then a random name 'xrd-terraform-[0-9a-z]{8}' is used.
  EOT
  type        = string
  default     = null
}

variable "azs" {
  description = <<-EOT
  List of exactly two availability zones in the currently configured AWS region.
  A private subnet and a public subnet is created in each of these availability zones.
  Each cluster node is launched in one of the private subnets.
  If null, then the first two availability zones in the currently configured AWS region is used.
  EOT
  type        = list(string)
  default     = null

  validation {
    condition     = try(length(var.azs) == 2, var.azs == null)
    error_message = "Must provide exactly two availability zones."
  }
}

variable "bastion_remote_access_cidr_blocks" {
  description = <<-EOT
  Allowed CIDR blocks for external SSH access to the Bastion instance.
  This must be a list of strings.
  If null, then access to the Bastion instance is prevented.
  EOT
  type        = list(string)
}

variable "cluster_version" {
  description = "Cluster version"
  type        = string
  default     = "1.30"
  nullable    = false
}
