
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "cost_alert_sns_topic_arn" {
  value = aws_sns_topic.cost_alerts.arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_cost_ops.arn
}

output "aws_load_balancer_controller_role_arn" {
  value = aws_iam_role.aws_load_balancer_controller.arn
}

output "region" {
  description = "AWS region in use"
  value       = var.region
}

output "nodegroup_names" {
  description = "EKS managed node group names"
  value       = module.eks.nodegroup_names
}

output "github_runner_instance_id" {
  description = "EC2 instance ID of GitHub self-hosted runner (null if disabled)"
  value       = var.enable_github_runner ? aws_instance.github_runner[0].id : null
}

output "github_runner_private_ip" {
  description = "Private IP of GitHub self-hosted runner (null if disabled)"
  value       = var.enable_github_runner ? aws_instance.github_runner[0].private_ip : null
}

output "rds_endpoint" {
  value = aws_db_instance.petclinic.address
}

output "rds_port" {
  value = aws_db_instance.petclinic.port
}

output "rds_identifier" {
  value = aws_db_instance.petclinic.id
}

# output "cur_bucket_name" {
#   value = aws_s3_bucket.cur.bucket
# }

# output "athena_workgroup_name" {
#   value = aws_athena_workgroup.cost.name
# }
