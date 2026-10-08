data "aws_iam_policy_document" "github_plan_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:pull_request"]

    }
  }
}

# 1b — the role a PR run assumes. Trust policy above restricts it to pull_request tokens.
resource "aws_iam_role" "github_actions_plan" {
  name               = "${var.cluster_name}-gha-plan-role"
  assume_role_policy = data.aws_iam_policy_document.github_plan_assume_role.json

  tags = var.default_tags
}

# State bucket is SSE-KMS; the key is owned by the backend root, so look it up by alias
data "aws_kms_key" "terraform_state" {
  key_id = "alias/terraform-state-backend"
}

data "aws_iam_policy_document" "github_plan_state" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::petclinic-terraform-state-589077667712"]
  }

  statement {
    sid       = "ReadStateObjects"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::petclinic-terraform-state-589077667712/*"]
  }

  statement {
    sid       = "DecryptState"
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_key.terraform_state.arn]
  }
}

# 1c — plan reads the state file. List the bucket, get the object. No Put: plan runs with -lock=false.
data "aws_iam_policy_document" "github_plan_read" {

  # VPC, subnets, NAT, SGs, EC2 runner, AMIs, VPC endpoints
  statement {
    sid = "Ec2Read"

    actions = [
      "ec2:Describe*"
    ]

    resources = ["*"]
  }

  # EKS cluster, node groups, addons and access entries
  statement {
    sid = "EksRead"

    actions = [
      "eks:DescribeCluster",
      "eks:DescribeNodegroup",
      "eks:DescribeAddon",
      "eks:ListNodegroups",
      "eks:ListAddons",
      "eks:ListAccessEntries",
      "eks:DescribeAccessEntry",
      "eks:ListAssociatedAccessPolicies",
      "eks:ListTagsForResource",
      "eks:DescribePodIdentityAssociation",
      "eks:ListPodIdentityAssociations"
    ]

    resources = ["*"]
  }

  # Terraform-managed IAM roles/policies
  statement {
    sid = "IamRead"

    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetInstanceProfile",
      "iam:GetOpenIDConnectProvider",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListPolicyVersions",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRoleTags",
      "iam:ListPolicyTags"
    ]

    resources = ["*"]
  }

  # RDS
  statement {
    sid = "RdsRead"

    actions = [
      "rds:DescribeDBInstances",
      "rds:DescribeDBSubnetGroups",
      "rds:ListTagsForResource"
    ]

    resources = ["*"]
  }

  # KMS keys used by EKS/RDS/etc.
  statement {
    sid = "KmsRead"

    actions = [
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags",
      "kms:ListAliases"
    ]

    resources = ["*"]
  }

  # Cost notification SNS topic
  statement {
    sid = "SnsRead"

    actions = [
      "sns:GetTopicAttributes",
      "sns:GetSubscriptionAttributes",
      "sns:ListSubscriptionsByTopic",
      "sns:ListTagsForResource"
    ]

    resources = ["*"]
  }

  # AWS Budgets
  statement {
    sid = "BudgetsRead"

    actions = [
      "budgets:ViewBudget",
      "budgets:Describe*",
      "budgets:ListTagsForResource"
    ]

    resources = ["*"]
  }

  # Provider uses this for account ID
  statement {
    sid = "Identity"

    actions = [
      "sts:GetCallerIdentity"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "${var.cluster_name}-gha-plan-state"
  role   = aws_iam_role.github_actions_plan.id
  policy = data.aws_iam_policy_document.github_plan_state.json
}
resource "aws_iam_role_policy" "github_plan_read" {
  name   = "${var.cluster_name}-gha-plan-read"
  role   = aws_iam_role.github_actions_plan.id
  policy = data.aws_iam_policy_document.github_plan_read.json
}
