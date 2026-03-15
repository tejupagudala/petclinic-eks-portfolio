
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

# output "cur_bucket_name" {
#   value = aws_s3_bucket.cur.bucket
# }

# output "athena_workgroup_name" {
#   value = aws_athena_workgroup.cost.name
# }