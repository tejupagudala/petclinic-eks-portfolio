# data "aws_caller_identity" "current" {}
# data "aws_partition" "current" {}


locals {
  budget_notifications = [
    { threshold = 50, type = "ACTUAL" },
    { threshold = 80, type = "FORECASTED" },
    { threshold = 100, type = "ACTUAL" }
  ]

  service_budgets = {
    eks       = { service = "Amazon Elastic Container Service for Kubernetes", limit = var.eks_budget_limit_usd }
    ec2_other = { service = "EC2 - Other", limit = var.ec2_other_budget_limit_usd }
    vpc       = { service = "Amazon Virtual Private Cloud", limit = var.vpc_budget_limit_usd }
    elb       = { service = "Amazon Elastic Load Balancing", limit = var.elb_budget_limit_usd }
  }
}

resource "aws_sns_topic" "cost_alerts" {
  name = "${var.cluster_name}-cost-alerts"
}

resource "aws_sns_topic_subscription" "cost_email" {
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_budgets_budget" "monthly_total" {
  name         = "${var.cluster_name}-monthly-total"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = local.budget_notifications
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.type
      subscriber_email_addresses = [var.alert_email]
      subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts.arn]
    }
  }
}

resource "aws_budgets_budget" "service_budgets" {
  for_each = local.service_budgets

  name         = "${var.cluster_name}-${each.key}-monthly"
  budget_type  = "COST"
  limit_amount = each.value.limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = [each.value.service]
  }

  dynamic "notification" {
    for_each = local.budget_notifications
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.type
      subscriber_email_addresses = [var.alert_email]
      subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts.arn]
    }
  }
}

resource "aws_ce_anomaly_monitor" "service_monitor" {
  count             = var.existing_anomaly_monitor_arn == "" ? 1 : 0
  name              = "${var.cluster_name}-service-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}


locals {
  service_monitor_arn = var.existing_anomaly_monitor_arn != "" ? var.existing_anomaly_monitor_arn : aws_ce_anomaly_monitor.service_monitor[0].arn
}

resource "aws_ce_anomaly_subscription" "daily_anomaly" {
  name             = "${var.cluster_name}-daily-anomaly-subscription"
  frequency        = "DAILY"
  monitor_arn_list = [local.service_monitor_arn]
  threshold_expression {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = ["1"]
        match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }

  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.github_oidc_provider_arn == "" ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  github_oidc_provider_arn = var.github_oidc_provider_arn != "" ? var.github_oidc_provider_arn : aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "github_assume_role" {
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
      values   = ["repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

resource "aws_iam_role" "github_actions_cost_ops" {
  name               = "${var.cluster_name}-gha-cost-ops-role"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
  tags               = var.default_tags
}

data "aws_iam_policy_document" "github_actions_cost_ops" {
  statement {
    sid = "CostExplorerRead"
    actions = [
      "ce:GetCostAndUsage",
      "ce:GetCostForecast",
      "ce:GetAnomalies",
      "ce:GetDimensionValues"
    ]
    resources = ["*"]
  }

  statement {
    sid = "BudgetsRead"
    actions = [
      "budgets:ViewBudget",
      "budgets:Describe*"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "SnsPublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.cost_alerts.arn]
  }

  statement {
    sid = "EksScaleNodegroup"
    actions = [
      "eks:DescribeCluster",
      "eks:DescribeNodegroup",
      "eks:ListNodegroups",
      "eks:UpdateNodegroupConfig"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_actions_cost_ops" {
  name   = "${var.cluster_name}-gha-cost-ops-policy"
  policy = data.aws_iam_policy_document.github_actions_cost_ops.json
}

resource "aws_iam_role_policy_attachment" "github_actions_cost_ops" {
  role       = aws_iam_role.github_actions_cost_ops.name
  policy_arn = aws_iam_policy.github_actions_cost_ops.arn
}

# resource "aws_s3_bucket" "cur" {
#   bucket        = "${var.cluster_name}-${data.aws_caller_identity.current.account_id}-cur"
#   force_destroy = true
#   tags          = var.default_tags
# }

# resource "aws_s3_bucket_public_access_block" "cur" {
#   bucket                  = aws_s3_bucket.cur.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# data "aws_iam_policy_document" "cur_bucket_policy" {
#   statement {
#     sid = "AllowCURDelivery"
#     principals {
#       type        = "Service"
#       identifiers = ["billingreports.amazonaws.com"]
#     }

#     actions = ["s3:GetBucketAcl", "s3:GetBucketPolicy", "s3:PutObject"]
#     resources = [
#       aws_s3_bucket.cur.arn,
#       "${aws_s3_bucket.cur.arn}/*"
#     ]

#     condition {
#       test     = "StringEquals"
#       variable = "aws:SourceAccount"
#       values   = [data.aws_caller_identity.current.account_id]
#     }

#     #     condition {
#     #   test     = "StringLike"
#     #   variable = "aws:SourceArn"
#     #   values   = ["arn:${data.aws_partition.current.partition}:cur:us-east-1:${data.aws_caller_identity.current.account_id}:definition/*"]
#     # }
#   }
# }

# resource "aws_s3_bucket_policy" "cur" {
#   bucket = aws_s3_bucket.cur.id
#   policy = data.aws_iam_policy_document.cur_bucket_policy.json
# }

# resource "aws_cur_report_definition" "cur_daily" {
#   report_name                = "${var.cluster_name}-daily-cur"
#   time_unit                  = "DAILY"
#   format                     = "Parquet"
#   compression                = "Parquet"
#   additional_schema_elements = ["RESOURCES"]
#   s3_bucket                  = aws_s3_bucket.cur.id
#   s3_region                  = var.region
#   s3_prefix                  = "cur"
#   additional_artifacts       = ["ATHENA"]
#   report_versioning          = "OVERWRITE_REPORT"
#   refresh_closed_reports     = true

#   depends_on = [aws_s3_bucket_policy.cur]
# }

# resource "aws_athena_workgroup" "cost" {
#   name = "${var.cluster_name}-cost-wg"

#   configuration {
#     result_configuration {
#       output_location = "s3://${aws_s3_bucket.cur.bucket}/athena-results/"
#     }
#   }

#   tags = var.default_tags
# }


