variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "cluster_subnet_ids" {
  description = "Subnets for the EKS control-plane ENIs (the private-app tier, at least two AZs)"
  type        = list(string)
}

variable "public_endpoint_enabled" {
  description = "Whether the EKS public endpoint is enabled"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to access the public EKS endpoint (ignored if public endpoint disabled)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "node_groups" {
  description = "Managed node groups, keyed by name. Each states where it lives (subnet_ids) and what it attracts or repels (labels, taints)"
  type = map(object({
    subnet_ids     = list(string)
    instance_types = list(string)
    capacity_type  = string
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    scaling_config = object({
      desired_size = number
      max_size     = number
      min_size     = number
    })
  }))
}
