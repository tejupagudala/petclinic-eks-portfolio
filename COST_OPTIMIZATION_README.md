# Cost Optimization Runbook (Terraform + GitHub Actions)

This document captures all cost-optimization changes implemented in this project, how to validate them, and the exact issues we hit and how we fixed them.

## Why We Implemented This

We implemented this cost-optimization plan after discovering unexpected EKS billing tied to Kubernetes version support lifecycle (extended support charges on a deprecated version). That incident showed that monthly total spend alone was not enough. We needed daily visibility and alerts broken down by service and usage type so we could quickly detect exactly what was charging the account and prevent surprise bills.

## 1) What We Changed

### Terraform (`terraform/cost_guardrails.tf`)
- Added `aws_sns_topic.cost_alerts` and `aws_sns_topic_subscription.cost_email`.
  - Purpose: send daily cost alerts to Gmail when the workflow flags a threshold breach.
- Added monthly total budget (`aws_budgets_budget.monthly_total`).
  - Purpose: alert at 50%, 80% forecast, and 100% actual spend.
- Added per-service budgets (`aws_budgets_budget.service_budgets`) for:
  - EKS
  - EC2-Other
  - VPC
  - ELB
  - Purpose: detect which service family is causing spend.
- Added Cost Anomaly Detection:
  - `aws_ce_anomaly_monitor.service_monitor` (with optional reuse of existing monitor ARN)
  - `aws_ce_anomaly_subscription.daily_anomaly`
  - Purpose: daily anomaly email if sudden cost spike occurs.
- Added GitHub OIDC trust and IAM role/policy:
  - `aws_iam_openid_connect_provider.github`
  - `aws_iam_role.github_actions_cost_ops`
  - `aws_iam_policy.github_actions_cost_ops`
  - Purpose: GitHub Actions can call AWS APIs without static AWS keys.
- CUR/Athena resources are intentionally commented out.
  - Purpose: avoid extra setup/cost right now.

### Terraform variables (`terraform/variables.tf`)
- Added/used cost-related variables:
  - `alert_email`
  - `monthly_budget_limit_usd`
  - `eks_budget_limit_usd`
  - `ec2_other_budget_limit_usd`
  - `vpc_budget_limit_usd`
  - `elb_budget_limit_usd`
  - `existing_anomaly_monitor_arn`
  - `github_org`, `github_repo`, `github_branch`, `github_oidc_provider_arn`
- Kept low-cost defaults:
  - Spot nodegroup
  - small instance type
  - minimal default node counts

### Terraform outputs (`terraform/outputs.tf`)
- Added outputs:
  - `cost_alert_sns_topic_arn`
  - `github_actions_role_arn`
- Purpose: use these directly as GitHub Secrets values.

### GitHub Workflows
- `.github/workflows/cost-report-daily.yaml`
  - Daily (8 AM Chicago approx via cron) + manual trigger.
  - Produces:
    - `cost-report.txt`
    - `by-service.json`
    - `by-usage-type.json`
  - Sends an SNS email alert when the daily total exceeds `DAILY_COST_LIMIT_USD` or risky usage types are detected.
  - Fails run when daily cost limit is exceeded or risky usage types detected.
- `.github/workflows/non-prod-stop.yaml`
  - Night schedule + manual trigger.
  - Scales EKS nodegroup to `desiredSize=0`.
- `.github/workflows/non-prod-start.yaml`
  - Morning schedule + manual trigger.
  - Scales EKS nodegroup to `desiredSize=2`.
- `.github/workflows/finops-weekly.yaml`
  - Present but commented out (optional).

### Terraform VPC change (`terraform/modules/vpc/main.tf`)
- NAT gateways reduced to 1 (`count = 1`) instead of 3.
- Purpose: major monthly cost reduction.

## 2) Why These Changes Matter

- Budgets: prevent silent monthly overrun.
- Service budgets: identify exactly where spend is coming from.
- Anomaly detection: catch unusual spend early.
- Daily report workflow: gives day-by-day spend attribution.
- Non-prod stop/start: avoids paying for worker nodes overnight.
- OIDC role: secure automation with no long-lived AWS keys.
- Single NAT: large baseline networking cost reduction.

## 3) Step-by-Step Setup (From Current Repo)

## Step 1: Apply Terraform from the correct directory

```bash
cd terraform
terraform init -input=false
terraform apply \
  -var="github_org=YOUR_GITHUB_ORG" \
  -var="github_repo=YOUR_REPO_NAME" \
  -var="alert_email=YOUR_GMAIL"
```

Important:
- Run from `terraform/` directory only.
- If your account already has a Cost Anomaly Monitor limit issue, pass:

```bash
-var="existing_anomaly_monitor_arn=arn:aws:ce::ACCOUNT_ID:anomalymonitor/XXXX"
```

## Step 2: Confirm SNS email subscription

- Check Gmail for AWS SNS subscription email.
- Click **Confirm subscription**.

If not confirmed, daily alert emails will not arrive.

## Step 3: Get values for GitHub Secrets

```bash
# from terraform outputs
terraform output github_actions_role_arn
terraform output cost_alert_sns_topic_arn

# cluster/nodegroup values
AWS_PROFILE=myaccount aws eks list-clusters --region us-east-1
AWS_PROFILE=myaccount aws eks list-nodegroups --cluster-name demo-eks-cluster --region us-east-1
```

## Step 4: Add GitHub repository secrets

In GitHub: `Settings -> Secrets and variables -> Actions -> New repository secret`

Add:
- `AWS_ROLE_ARN` = output `github_actions_role_arn`
- `AWS_REGION` = `us-east-1`
- `COST_ALERT_SNS_TOPIC_ARN` = output `cost_alert_sns_topic_arn`
- `DAILY_COST_LIMIT_USD` = e.g. `1.00`
- `EKS_CLUSTER_NAME` = `demo-eks-cluster`
- `EKS_NODEGROUP_NAME` = from `aws eks list-nodegroups` result

## Step 5: Validate daily report workflow

- GitHub Actions -> `cost-report-daily` -> **Run workflow**
- Confirm:
  - run succeeds (or intentionally fails when threshold test is low)
  - artifact `cost-report-daily` exists with files:
    - `cost-report.txt`
    - `by-service.json`
    - `by-usage-type.json`
  - Gmail receives `AWS Daily Cost Alert` when the daily report exceeds the configured limit

## Step 6: Validate stop/start workflows

### Test stop
- Run `non-prod-stop` manually.
- Verify nodegroup:

```bash
AWS_PROFILE=myaccount aws eks describe-nodegroup \
  --cluster-name demo-eks-cluster \
  --nodegroup-name YOUR_NODEGROUP \
  --region us-east-1 \
  --query 'nodegroup.scalingConfig' --output table
```

Expected after stop: desired size `0`.

### Test start
- Run `non-prod-start` manually.
- Verify same command.

Expected after start: desired size `2`.

## Step 7: Validate EKS support status (avoid surprise support charges)

```bash
AWS_PROFILE=myaccount aws eks describe-cluster \
  --name demo-eks-cluster \
  --region us-east-1 \
  --query 'cluster.{version:version,supportType:upgradePolicy.supportType,status:status}' \
  --output table

VER=$(AWS_PROFILE=myaccount aws eks describe-cluster \
  --name demo-eks-cluster --region us-east-1 \
  --query 'cluster.version' --output text)

AWS_PROFILE=myaccount aws eks describe-cluster-versions \
  --region us-east-1 \
  --cluster-versions "$VER" \
  --query 'clusterVersions[0].{clusterVersion:clusterVersion,status:status}' \
  --output table
```

Use this to track if your running version is in standard support.

## 4) Issues We Faced and Fixes

1. Terraform run from repo root
- Error: `Terraform initialized in an empty directory` / `No configuration files`
- Fix: run from `terraform/`.

2. Wrong variable name typo
- Error: `existing_anamoly_monitor_arn` undeclared
- Fix: use exact variable `existing_anomaly_monitor_arn`.

3. Missing variable declaration
- Error: `var.github_repo` referenced but variable missing
- Fix: added `github_repo` variable in `terraform/variables.tf`.

4. Anomaly monitor quota limit
- Error: `Limit exceeded on dimensional spend monitor creation`
- Fix: reused existing monitor ARN via `existing_anomaly_monitor_arn` instead of creating a new one.

5. Subscription block syntax mismatch
- Error: `Too few blocks specified for "subscriber"`
- Fix: used proper `subscriber {}` block in `aws_ce_anomaly_subscription`.

6. Unsupported attribute in subscription
- Error: `Unexpected attribute: threshold`
- Fix: replaced with `threshold_expression` block supported by provider/API.

7. Count/index reference issue
- Error: `Missing resource instance key` on anomaly monitor ARN
- Fix: used local fallback with indexed reference `aws_ce_anomaly_monitor.service_monitor[0].arn`.

8. Invalid threshold expression shape
- Error: `And expression must have at least 2 operands`
- Fix: simplified to valid single `dimension` threshold expression.

9. Daily frequency subscriber constraints
- Error: `Daily or weekly frequencies only support Email subscriptions`
- Fix: kept anomaly subscription as EMAIL only.

10. Nodegroup workflow failed
- Error: `nodegroup name contains invalid characters`
- Fix: corrected `EKS_NODEGROUP_NAME` secret to exact nodegroup name from AWS CLI output.

11. Cost value misread
- Confusion: tiny values looked like dollars (e.g. `0.0000007795` interpreted as `7.795`)
- Fix: report formatting now keeps very small values with more decimals.

## 5) How to Keep Daily Cost Low

- Keep stop/start workflows enabled and secrets correct.
- Use single NAT gateway.
- Keep nodegroup at zero when idle.
- Use low `DAILY_COST_LIMIT_USD` (example `1.00`) for early warning.
- Keep EKS version in standard support.
- Destroy stack when not using for longer periods:

```bash
cd terraform
terraform destroy \
  -var="github_org=YOUR_GITHUB_ORG" \
  -var="github_repo=YOUR_REPO_NAME" \
  -var="alert_email=YOUR_GMAIL"
```

Note: if backend S3/DynamoDB state-lock infrastructure is intentionally kept, tiny backend charges may still exist.

## 6) Quick Validation Checklist

- [ ] Terraform apply succeeded from `terraform/`
- [ ] SNS email subscription confirmed in Gmail
- [ ] GitHub secrets set correctly
- [ ] `cost-report-daily` workflow creates artifact
- [ ] `cost-report-daily` sends Gmail alert when daily usage exceeds the configured limit
- [ ] `non-prod-stop` sets desired nodes to 0
- [ ] `non-prod-start` sets desired nodes to 2
- [ ] EKS version/support status verified
- [ ] Daily report reviewed for top SERVICE and USAGE_TYPE spend

command to test if the node group has scaled up 

AWS_PROFILE=myaccount aws eks describe-nodegroup \
  --cluster-name demo-eks-cluster \
  --nodegroup-name demo-eks-cluster-node-group-demo-node-group \
  --region us-east-1 \
  --query 'nodegroup.scalingConfig' \
  --output table
