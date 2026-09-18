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

# 1c — plan calls Describe*/Get* on every resource in state. AWS-managed read-only covers all of it.
resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.github_actions_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# State bucket is SSE-KMS; the key is owned by the backend root, so look it up by alias
data "aws_kms_key" "terraform_state" {
  key_id = "alias/terraform-state-backend"
}

# 1c — plan reads the state file. List the bucket, get the object. No Put: plan runs with -lock=false.
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

resource "aws_iam_role_policy" "plan_state" {
  name   = "${var.cluster_name}-gha-plan-state"
  role   = aws_iam_role.github_actions_plan.id
  policy = data.aws_iam_policy_document.github_plan_state.json
}
