variable "create_vpc" {
  type        = bool
  default     = true
}

variable "name" {
  type        = string
  default     = ""
}

variable "cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  type        = list(string)
  default     = []
}

variable "enable_dns_hostnames" {
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  type        = bool
  default     = true
}

variable "vpc_tags" {
  type        = map(string)
  default     = {}
}

variable "tags" {
  type        = map(string)
  default     = {}
}

variable "public_subnets" {
  type        = list(string)
  default     = []
}

variable "map_public_ip_on_launch" {
  type        = bool
  default     = false
}

variable "public_subnet_names" {
  type        = list(string)
  default     = []
}

variable "public_subnet_suffix" {
  type        = string
  default     = "public"
}

variable "public_subnet_tags" {
  type        = map(string)
  default     = {}
}

variable "private_subnets" {
  type        = list(string)
  default     = []
}

variable "private_subnet_names" {
  type        = list(string)
  default     = []
}

variable "private_subnet_suffix" {
  type        = string
  default     = "private"
}

variable "private_subnet_tags" {
  type        = map(string)
  default     = {}
}

variable "intra_subnets" {
  type        = list(string)
  default     = []
}

variable "intra_subnet_names" {
  type        = list(string)
  default     = []
}

variable "intra_subnet_suffix" {
  type        = string
  default     = "intra"
}

variable "intra_subnet_tags" {
  type        = map(string)
  default     = {}
}

variable "create_igw" {
  type        = bool
  default     = true
}

variable "igw_tags" {
  type        = map(string)
  default     = {}
}

variable "enable_nat_gateway" {
  type        = bool
  default     = false
}

variable "nat_gateway_tags" {
  type        = map(string)
  default     = {}
}
