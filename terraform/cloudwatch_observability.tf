resource "aws_iam_role" "cloudwatch_observability_pod_identity" {
  name = "${var.cluster_name}-cloudwatch-observability-pod-identity"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEksAuthToAssumeRoleForPodIdentity"
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes-service-account" = "cloudwatch-agent"
          }
        }
      }
    ]
  })

  tags = var.default_tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability_agent" {
  role       = aws_iam_role.cloudwatch_observability_pod_identity.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "amazon-cloudwatch-observability"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  pod_identity_association {
    service_account = "cloudwatch-agent"
    role_arn        = aws_iam_role.cloudwatch_observability_pod_identity.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.cloudwatch_observability_agent,
    aws_eks_addon.eks_pod_identity_agent
  ]
}
