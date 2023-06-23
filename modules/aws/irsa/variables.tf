variable "role_name" {
  description = "Name of the IRSA IAM role to create. If not specified this is auto-generated"
  type        = string
  default     = null
}

variable "role_policies" {
  description = "List of role policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "oidc_issuer" {
  description = "OIDC issuer URL of the EKS cluster to create an IRSA IAM role for"
  type        = string
}

variable "oidc_provider" {
  description = "OIDC provider ARN of the EKS cluster to create an IRSA IAM role for"
  type        = string
}

variable "namespace" {
  description = "Namespace of the service account to create the role for. Use '*' for a wildcard"
  type        = string
}

variable "service_account" {
  description = "Name of the service account to create the role for. Use '*' for a wildcard"
  type        = string
}
