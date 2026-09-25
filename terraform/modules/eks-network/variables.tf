variable "name" {
  description = "Prefix for every resource name, e.g. petclinic"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name. Used in the kubernetes.io subnet tags the AWS Load Balancer Controller reads"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC address range, e.g. 10.0.0.0/16"
  type        = string
}

variable "availability_zones" {
  description = "AZs to build in. One subnet per tier is created in each"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Public tier, one CIDR per AZ in AZ order. Holds only the ALB and NAT gateways"
  type        = list(string)
}

variable "app_subnet_cidrs" {
  description = "Private-app tier, one CIDR per AZ. Size for pod count: the VPC CNI gives every pod a VPC IP"
  type        = list(string)
}

variable "data_subnet_cidrs" {
  description = "Private-data tier, one CIDR per AZ. RDS only; the route table has no default route"
  type        = list(string)
}

variable "nat_per_az" {
  description = "true = one NAT gateway per AZ (prod: an AZ failure stays in that AZ). false = one NAT total (non-prod cost option)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}
