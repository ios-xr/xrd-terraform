variable "cluster_version" {
  description = "Kubernetes version to search for"
  type        = string
  nullable    = false
}

variable "filters" {
  description = "Additional filters to apply to the image search. Same format as regular AWS filters."
  type = list(object({
    name : string
    values : list(string)
  }))
  default  = []
  nullable = false
}