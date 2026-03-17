
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "nodegroup_names" {
  description = "EKS managed node group names"
  value       = [for ng in aws_eks_node_group.node_groups : ng.node_group_name]
}
