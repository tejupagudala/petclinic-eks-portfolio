
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "profile_name" {
  description = "AWS profile name for local CLI usage (leave empty in CI/OIDC)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "demo-eks-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.32"
}

# GitHub OIDC + repo metadata
variable "github_org" {
  description = "GitHub repository name"
  type        = string

}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "petclinic-eks-portfolio-1"
}

variable "github_branch" {
  description = "Branch allowed to assume GitHub OIDC role"
  type        = string
  default     = "main"
}

# Optional: if OIDC provider already exists in account, pass its ARN
variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN (optional)"
  type        = string
  default     = ""
}

# Gmail alert destination
variable "alert_email" {
  description = "Email to receive budget/anomaly/daily cost alerts"
  type        = string
}

# Budget limits
variable "monthly_budget_limit_usd" {
  type    = string
  default = "20"
}

variable "eks_budget_limit_usd" {
  type    = string
  default = "10"
}

variable "ec2_other_budget_limit_usd" {
  type    = string
  default = "5"
}

variable "vpc_budget_limit_usd" {
  type    = string
  default = "5"
}

variable "elb_budget_limit_usd" {
  type    = string
  default = "5"
}

# Mandatory cost tags
variable "default_tags" {
  description = "Mandatory tags for all Terraform-managed resources"
  type        = map(string)
  default = {
    project     = "petclinic"
    environment = "portfolio"
    owner       = "sai"
    managed_by  = "terraform"
  }
}

variable "existing_anomaly_monitor_arn" {
  description = "Existing Cost Anomaly Monitor ARN to reuse"
  type        = string
  default     = ""
}

variable "enable_cost_anomaly_detection" {
  description = "Enable Cost Anomaly Detection monitor/subscription resources"
  type        = bool
  default     = true
}


variable "node_groups" {
  description = "EKS node group configuration"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    scaling_config = object({
      desired_size = number
      max_size     = number
      min_size     = number
    })
  }))
  default = {
    "demo-node-group" = {
      instance_types = ["t3.small"]
      capacity_type  = "SPOT"
      scaling_config = {
        desired_size = 1
        max_size     = 1
        min_size     = 1
      }
    }
  }
}

variable "aws_auth_role_arns" {
  description = "IAM role ARNs to grant cluster-admin access via aws-auth"
  type        = list(string)
  default     = []
}

# Optional: self-hosted GitHub runner EC2 (cost-controlled)
variable "enable_github_runner" {
  description = "Whether to create an EC2 instance for GitHub self-hosted runner"
  type        = bool
  default     = false
}

variable "github_runner_instance_type" {
  description = "EC2 instance type for GitHub runner"
  type        = string
  default     = "t3.small"
}

variable "github_runner_subnet_id" {
  description = "Subnet ID for GitHub runner instance. If empty, first private subnet is used."
  type        = string
  default     = ""
}

variable "github_runner_ami_id" {
  description = "AMI ID for GitHub runner instance. If empty, latest Amazon Linux 2023 AMI is used."
  type        = string
  default     = ""
}

variable "github_runner_key_name" {
  description = "Optional EC2 key pair name for GitHub runner instance"
  type        = string
  default     = ""
}

variable "github_runner_root_volume_size" {
  description = "Root EBS size (GiB) for GitHub runner instance"
  type        = number
  default     = 30
}

variable "github_runner_allowed_ssh_cidrs" {
  description = "Optional list of CIDRs allowed to SSH into runner. Keep empty to disable SSH ingress."
  type        = list(string)
  default     = []
}
