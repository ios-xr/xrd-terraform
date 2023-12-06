variable "aws_endpoint" {
  description = "AWS endpoint URL"
  type        = string
  nullable    = false
}

variable "ami" {
  description = "AMI to launch the worker node with"
  type        = string
  nullable    = false
}

variable "is_xrd_ami" {
  description = <<-EOT
  Is the given AMI capable of running an XRd workload?
  If null, default is to check whether the given AMI is generated by the XRd Packer template.
  EOT
  type        = bool
  default     = null
}

variable "cluster_name" {
  description = "Name of the EKS cluster the node should join"
  type        = string
  nullable    = false
}

variable "iam_instance_profile" {
  description = <<-EOT
  IAM instance profile to apply to the node.
  This should be a profile that allows the node to join the given EKS cluster.
  EOT
  type        = string
  nullable    = false
}

variable "key_name" {
  description = "Key pair name to install on the node"
  type        = string
  nullable    = false
}

variable "name" {
  description = "Name for the worker node instance"
  type        = string
  nullable    = false
}

variable "private_ip_address" {
  description = "Primary private IPv4 address for the node"
  type        = string
  nullable    = false
}

variable "secondary_private_ips" {
  description = "List of secondary private IPv4 addresses to assign to the node's primary network interface"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "security_groups" {
  description = "List of security group IDs to apply to the node's primary interface"
  type        = list(string)
  nullable    = false
}

variable "subnet_id" {
  description = "Subnet ID for the node's primary interface"
  type        = string
  nullable    = false
}

variable "hugepages_gb" {
  description = <<-EOT
  Number of 1GiB hugepages to allocate.
  This is ignored if not using an XRd AMI generated by Packer.
  If null, a number appropriate for the instance type is used.
  EOT
  type        = number
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type to create"
  type        = string
  default     = "m5.2xlarge"
  nullable    = false
}

variable "isolated_cores" {
  description = <<-EOT
  CPU cores to isolate.
  This should be an inclusive range: "<start-number>-<end-number>".
  This is ignored if not using an XRd AMI generated by Packer.
  If null, this is calculated from the 'vr_cpuset' and 'vr_cp_num_cpus' variables.
  EOT
  type        = string
  default     = null
}

variable "kubelet_extra_args" {
  description = <<-EOT
  Extra arguments to pass to kubelet when booting the node.
  Note that node labels must be specified via the 'labels' variable.
  EOT
  type        = string
  default     = null
}

variable "labels" {
  description = "Node labels to set"
  type        = map(string)
  default     = null
}

variable "network_interfaces" {
  description = "Configuration for secondary interfaces for the node"
  type = list(object({
    private_ips : list(string)
    security_groups : list(string)
    subnet_id : string
  }))
  default = []
}

variable "placement_group" {
  description = <<-EOT
  Placement group to launch the node into.
  Placement groups can be used to align instances to the same (or nearby) compute, thus minimizing expected network latency between the two.
  They can also be used to spread the instances apart.
  By default the node is not added to a placement group.
  EOT
  type        = string
  default     = null
}

variable "user_data" {
  description = "Custom user data to append to the EC2 node's user data"
  type        = string
  default     = ""
}

variable "wait" {
  description = "Wait for the instance to reach Ready status"
  type        = bool
  default     = true
  nullable    = false
}

variable "vr_cpuset" {
  description = <<-EOT
  If this node is intended for an XRd vRouter workload, this is the intended CPU set provided for XRd vRouter use.
  This should be an inclusive range: "<start-number>-<end-number>".
  This is ignored if not using an XRd AMI generated by Packer.
  This is ignored if the variable 'isolated_cores' is provided.
  If null, a range appropriate for the instance type is used.
  EOT
  type        = string
  default     = null
}

variable "vr_cp_num_cpus" {
  description = <<-EOT
  If this node is intended for an XRd vRouter workload, this is the intended number of control-plane CPUs.
  This is ignored if not using an XRd AMI generated by Packer.
  This is ignored if the variable 'isolated_cores' is provided.
  If null, a number appropriate for the instance type is used.
  EOT
  type        = number
  default     = null
}
