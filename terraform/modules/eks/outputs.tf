
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

output "nodegroup_names" {
  description = "EKS managed node group names"
  value       = [for ng in aws_eks_node_group.node_groups : ng.node_group_name]
}

output "node_group_role_arn" {
  description = "IAM role ARN used by EKS node groups"
  value       = aws_iam_role.eks_node_group_role.arn
}
