enable_github_runner          = true
github_runner_instance_type   = "t3.small"
enable_cost_anomaly_detection = false
existing_anomaly_monitor_arn  = ""
github_org                    = "tejupagudala"
github_repo                   = "petclinic-eks-portfolio"
github_branch                 = "main"

node_groups = {
  "demo-node-group" = {
    instance_types = ["t3.small"]
    capacity_type  = "SPOT"
    scaling_config = {
      desired_size = 3
      max_size     = 3
      min_size     = 1
    }
  }
}

# optional
# github_runner_allowed_ssh_cidrs = ["97.242.96.150/32"]
