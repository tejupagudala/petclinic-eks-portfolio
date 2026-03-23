
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_oidc_issuer" {
  description = "EKS cluster OIDC issuer URL"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "nodegroup_names" {
  description = "EKS managed node group names"
  value       = [for ng in aws_eks_node_group.node_groups : ng.node_group_name]
}

output "node_group_role_arn" {
  description = "IAM role ARN used by EKS node groups"
  value       = aws_iam_role.eks_node_group_role.arn
}

output "aws_load_balancer_controller_policy_arn" {
  description = "IAM policy ARN for AWS Load Balancer Controller"
  value       = aws_iam_policy.aws_load_balancer_controller.arn
}
