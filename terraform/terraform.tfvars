enable_github_runner          = true
github_runner_instance_type   = "t3.small"
enable_cost_anomaly_detection = false
existing_anomaly_monitor_arn  = ""
github_org                    = "tejupagudala"
github_repo                   = "petclinic-eks-portfolio"
github_branch                 = "main"
# Empty means Terraform creates the GitHub OIDC provider in this AWS account.
github_oidc_provider_arn    = "arn:aws:iam::589077667712:oidc-provider/token.actions.githubusercontent.com"
eks_public_endpoint_enabled = true
alert_email                 = "teju.654@gmail.com"
rds_instance_class          = "db.t4g.micro"
rds_allocated_storage       = 20
rds_username                = "petclinic"
eks_public_access_cidrs     = ["75.210.79.3/32"]


node_groups = {
  "demo-node-group" = {
    instance_types = ["t3.small"]
    capacity_type  = "SPOT"
    scaling_config = {
      desired_size = 6
      max_size     = 6
      min_size     = 1
    }
  }
}

# optional
# github_runner_allowed_ssh_cidrs = ["97.242.96.150/32"]
