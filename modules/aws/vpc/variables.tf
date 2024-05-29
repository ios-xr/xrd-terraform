variable "create_vpc" {
  description = "Controls if the VPC should be created (affects almost all resources)"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name to be used on all the resources as identifier"
  type        = string
  default     = ""
}

variable "cidr" {
  description = "The IPv4 CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "assign_generated_ipv6_cidr_block" {
  type        = bool
  default     = false
}

variable "azs" {
  description = "List of availability zones names or ids in the region"
  type        = list(string)
  default     = []
}

variable "enable_dns_hostnames" {
  description = "Whether to enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Whether to enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "vpc_tags" {
  description = "Additional tags for the VPC"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

################################################################################
# Publiс Subnets
################################################################################

variable "public_subnets" {
  description = "List of CIDR blocks to create public subnets for inside the VPC"
  type        = list(string)
  default     = []
}

variable "map_public_ip_on_launch" {
  description = "Specify `true` to indicate that instances launched in the public subnets should be assigned a public IP address. Default is `false`"
  type        = bool
  default     = false
}

variable "public_subnet_names" {
  description = "Explicit values to use in the Name tag on public subnets. If empty, Name tags are generated"
  type        = list(string)
  default     = []
}

variable "public_subnet_suffix" {
  description = "Suffix to append to the name of each public subnet"
  type        = string
  default     = "public"
}

variable "public_subnet_tags" {
  description = "Additional tags for the public subnets"
  type        = map(string)
  default     = {}
}

################################################################################
# Private Subnets
################################################################################

variable "private_subnets" {
  description = "List of CIDR blocks to create private subnets for inside the VPC"
  type        = list(string)
  default     = []
}

variable "private_subnet_names" {
  description = "Explicit values to use in the Name tag on private subnets. If empty, Name tags are generated"
  type        = list(string)
  default     = []
}

variable "private_subnet_suffix" {
  description = "Suffix to append to the name of each private subnet"
  type        = string
  default     = "private"
}

variable "private_subnet_tags" {
  description = "Additional tags for the private subnets"
  type        = map(string)
  default     = {}
}

################################################################################
# Intra Subnets
################################################################################

variable "intra_subnets" {
  description = "List of CIDR blocks to create intra subnets for inside the VPC"
  type        = list(string)
  default     = []
}

variable "intra_subnet_names" {
  description = "Explicit values to use in the Name tag on intra subnets. If empty, Name tags are generated"
  type        = list(string)
  default     = []
}

variable "intra_subnet_suffix" {
  description = "Suffix to append to the name of each intra subnet"
  type        = string
  default     = "intra"
}

variable "intra_subnet_tags" {
  description = "Additional tags for the intra subnets"
  type        = map(string)
  default     = {}
}

################################################################################
# Internet Gateway
################################################################################

variable "create_igw" {
  description = "Whether to create an Internet Gateway for public subnets and the related routes that connect them"
  type        = bool
  default     = true
}

variable "igw_tags" {
  description = "Additional tags for the internet gateway"
  type        = map(string)
  default     = {}
}

################################################################################
# NAT Gateway
################################################################################

variable "enable_nat_gateway" {
  description = "Whether to provision a NAT Gateway for private networks and the related routes that connect them"
  type        = bool
  default     = false
}

variable "nat_gateway_tags" {
  description = "Additional tags for the NAT gateway"
  type        = map(string)
  default     = {}
}
