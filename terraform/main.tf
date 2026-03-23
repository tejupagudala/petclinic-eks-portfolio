
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket       = "terraform-demo-eks-state-lock-bucket"
    key          = "terraform.lock.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile_name != "" ? var.profile_name : null

  default_tags {
    tags = var.default_tags
  }
}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  cluster_name         = var.cluster_name
}

module "eks" {
  tags   = var.default_tags
  source = "./modules/eks"

  cluster_name            = var.cluster_name
  cluster_version         = var.cluster_version
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  node_groups             = var.node_groups
  public_endpoint_enabled = var.eks_public_endpoint_enabled
  public_access_cidrs     = var.eks_public_access_cidrs
}

data "tls_certificate" "eks_oidc" {
  url = module.eks.cluster_oidc_issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = module.eks.cluster_oidc_issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "${var.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json
  tags               = var.default_tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = module.eks.aws_load_balancer_controller_policy_arn
}

resource "aws_security_group_rule" "github_runner_to_eks_api" {
  count = var.enable_github_runner ? 1 : 0

  type                     = "ingress"
  description              = "Allow self-hosted GitHub runner to reach the EKS private API"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = aws_security_group.github_runner[0].id

  depends_on = [module.eks, aws_security_group.github_runner]
}

resource "aws_eks_access_entry" "admin_roles" {
  for_each = toset(var.aws_auth_role_arns)

  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  type          = "STANDARD"

  depends_on = [module.eks]
}

resource "aws_eks_access_policy_association" "admin_roles" {
  for_each = toset(var.aws_auth_role_arns)

  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin_roles]
}

resource "aws_eks_access_entry" "github_actions_cost_ops" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions_cost_ops.arn
  type          = "STANDARD"

  depends_on = [module.eks, aws_iam_role.github_actions_cost_ops]
}

resource "aws_eks_access_policy_association" "github_actions_cost_ops" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions_cost_ops.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.github_actions_cost_ops]
}
