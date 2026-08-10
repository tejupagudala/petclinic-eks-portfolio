# Canary Deployment

This document captures the `api-gateway` canary deployment work implemented in this repo, the end-to-end steps we followed, the problems we hit, and how each issue was fixed.

## Goal

Add a safe production rollout path for `api-gateway` on EKS with:

- gradual traffic shifting
- manual approval before full promotion
- rollback support
- reuse of the existing AWS ALB and self-hosted runner model

## Final Design

The current design uses:

- GitHub Actions for CI and deployment orchestration
- Argo Rollouts for canary strategy
- AWS Load Balancer Controller for ALB traffic routing
- one existing ALB for both stable and canary traffic
- GitHub `production` environment approval before full rollout

Key files:

- [.github/workflows/ci.yaml](/Users/sai/petclinic-eks-portfolio-1/.github/workflows/ci.yaml)
- [.github/workflows/api-gateway-canary.yaml](/Users/sai/petclinic-eks-portfolio-1/.github/workflows/api-gateway-canary.yaml)
- [.github/workflows/infra-bootstrap.yaml](/Users/sai/petclinic-eks-portfolio-1/.github/workflows/infra-bootstrap.yaml)
- [kubernetes/api-gateway/deploy.yaml](/Users/sai/petclinic-eks-portfolio-1/kubernetes/api-gateway/deploy.yaml)
- [kubernetes/api-gateway/service.yaml](/Users/sai/petclinic-eks-portfolio-1/kubernetes/api-gateway/service.yaml)
- [kubernetes/api-gateway/ingress.yaml](/Users/sai/petclinic-eks-portfolio-1/kubernetes/api-gateway/ingress.yaml)

## What Changed

### 1. `api-gateway` moved from `Deployment` to `Rollout`

In [kubernetes/api-gateway/deploy.yaml](/Users/sai/petclinic-eks-portfolio-1/kubernetes/api-gateway/deploy.yaml):

- `kind: Deployment` became `kind: Rollout`
- canary strategy was added
- ALB traffic routing was added
- rollout steps were added:
  - `setWeight: 20`
  - `pause: {}`

This means a new `api-gateway` image now:

1. deploys as canary
2. receives 20% of traffic
3. pauses
4. waits for approval
5. either promotes or rolls back

### 2. One service became three services

In [kubernetes/api-gateway/service.yaml](/Users/sai/petclinic-eks-portfolio-1/kubernetes/api-gateway/service.yaml), we now have:

- `api-gateway`
- `api-gateway-stable`
- `api-gateway-canary`

Purpose:

- `api-gateway` is the root ALB action service
- `api-gateway-stable` points to the stable ReplicaSet
- `api-gateway-canary` points to the canary ReplicaSet

### 3. Ingress was updated for ALB-weighted routing

In [kubernetes/api-gateway/ingress.yaml](/Users/sai/petclinic-eks-portfolio-1/kubernetes/api-gateway/ingress.yaml):

- backend points to service `api-gateway`
- port name is `use-annotation`

This is required for ALB integration with Argo Rollouts. The ALB hostname stays the same; Rollouts only changes the backend weights behind it.

### 4. Canary deployment workflow was added

In [.github/workflows/api-gateway-canary.yaml](/Users/sai/petclinic-eks-portfolio-1/.github/workflows/api-gateway-canary.yaml):

- `deploy-canary` applies manifests and waits for canary pause
- smoke checks validate the canary service directly inside the cluster
- `promote` waits on GitHub `production` environment approval
- `rollback` aborts and undoes if promotion does not succeed
- `workflow_dispatch` was added so the workflow can be run manually

### 5. Bootstrap workflow was updated for Rollouts

In [.github/workflows/infra-bootstrap.yaml](/Users/sai/petclinic-eks-portfolio-1/.github/workflows/infra-bootstrap.yaml):

- Argo Rollouts controller install was added
- `kubectl argo rollouts` plugin install was added
- ALB controller readiness checks were fixed
- `TF_VAR_aws_auth_role_arns` was changed to `[]` to avoid duplicate access-entry creation
- Argo Rollouts install was pinned to `v1.8.3`

## CI/CD Flow

### CI

The current CI workflow in [.github/workflows/ci.yaml](/Users/sai/petclinic-eks-portfolio-1/.github/workflows/ci.yaml) runs on PRs to `main`.

Flow:

1. build `api-gateway`
2. run tests
3. run code-quality checks
4. run Trivy scans
5. build and push Docker image
6. update [kubernetes/api-gateway/deploy.yaml](/Users/sai/petclinic-eks-portfolio-1/kubernetes/api-gateway/deploy.yaml) on the PR branch with the new image tag

The `updatek8s` job commits a change like:

- `[CI]: Update api-gateway image tag to <github_run_id>`

### Canary deploy

After merge to `main`, [.github/workflows/api-gateway-canary.yaml](/Users/sai/petclinic-eks-portfolio-1/.github/workflows/api-gateway-canary.yaml) runs on:

- `push` to `main`
- or `workflow_dispatch`

Deploy flow:

1. apply `api-gateway` manifests
2. Argo Rollouts shifts 20% traffic to canary
3. rollout pauses at `CanaryPauseStep`
4. workflow smoke-tests `api-gateway-canary`
5. GitHub waits for `production` approval
6. if approved, rollout promotes to full traffic
7. if promotion fails or is rejected, rollback job runs

## End-to-End Steps We Followed

### 1. Bootstrapped infra

We used:

- Terraform backend for remote state
- `infra-bootstrap` to prepare the runner and apply the cluster stack

### 2. Enabled canary infrastructure

We updated:

- Rollout manifest
- stable/canary/root services
- ALB ingress
- Argo Rollouts install in bootstrap
- canary GitHub Actions workflow

### 3. Added a visible frontend canary marker

We used a low-risk frontend change in:

- [app/spring-petclinic-api-gateway/src/main/resources/static/scripts/fragments/welcome.html](/Users/sai/petclinic-eks-portfolio-1/app/spring-petclinic-api-gateway/src/main/resources/static/scripts/fragments/welcome.html)
- [app/spring-petclinic-api-gateway/src/main/resources/static/css/header.css](/Users/sai/petclinic-eks-portfolio-1/app/spring-petclinic-api-gateway/src/main/resources/static/css/header.css)

The visible marker was:

- `CANARY TEST BUILD`

This gave us a simple way to verify canary traffic in the browser.

### 4. Ran PR CI

We pushed changes to a child branch, opened a PR, and let `api-gateway-ci`:

- build the image
- push it to Docker Hub
- write the new image tag back into `deploy.yaml`

### 5. Merged to `main`

After merge:

- `api-gateway-canary` triggered on `main`
- canary rollout paused at 20%
- the same ALB URL served a mix of stable and canary traffic

### 6. Validated canary via ALB

We tested using the existing ALB, not a new one.

Example ALB discovered during testing:

- `http://k8s-petclini-frontend-8485b14cdc-1791457728.us-east-1.elb.amazonaws.com`

Important detail:

- this setup is path-based, not host-based
- no `Host: petclinic.local` header is required

### 7. Promoted after approval

After fixing the approval-stage OIDC issue, the `promote` job succeeded and the canary change became live at 100% traffic.

## Problems We Hit and Fixes

### Issue 1. Duplicate EKS access entry creation

Error:

- `ResourceInUseException: The specified access entry resource is already in use on this cluster`

Cause:

- the infra role already had an EKS access entry
- bootstrap was also trying to create it again through `TF_VAR_aws_auth_role_arns`

Fix:

In [.github/workflows/infra-bootstrap.yaml](/Users/sai/petclinic-eks-portfolio-1/.github/workflows/infra-bootstrap.yaml), changed:

```yaml
TF_VAR_aws_auth_role_arns: '[]'
```

This stopped Terraform from trying to recreate an existing access entry.

### Issue 2. ALB controller “stuck” after rollout restart

Observed behavior:

- deployment rollout completed
- workflow still failed waiting on ALB controller pods

Cause:

- workflow was waiting on pod readiness by label
- old terminating pods were still matched
- deployment was healthy, but pod wait was brittle

Fix:

In [.github/workflows/infra-bootstrap.yaml](/Users/sai/petclinic-eks-portfolio-1/.github/workflows/infra-bootstrap.yaml):

- replaced pod-level wait with deployment-level availability check

Used pattern:

```bash
kubectl -n kube-system rollout status deployment/aws-load-balancer-controller --timeout=600s
kubectl -n kube-system wait --for=condition=Available deployment/aws-load-balancer-controller --timeout=600s
```

### Issue 3. `timeout-minutes:: command not found`

Cause:

- `timeout-minutes:` was accidentally indented inside a shell `run` block

Fix:

- moved `timeout-minutes: 12` to the YAML step level

### Issue 4. Local `kubectl` could not access the cluster

Error:

- `You must be logged in to the server`

Cause:

- local IAM user was not part of EKS access entries
- only the GitHub infra role had cluster-admin access

Fix:

- used GitHub Actions runner and AWS CLI for deployment validation
- did not rely on local `kubectl` for rollout inspection

### Issue 5. OIDC failure on non-`main` branch

Error:

- `Not authorized to perform sts:AssumeRoleWithWebIdentity`

Cause:

- IAM trust policy allowed only:
  - `repo:tejupagudala/petclinic-eks-portfolio:ref:refs/heads/main`
- feature-branch runs were correctly denied

Resolution:

- kept deploy security `main`-only
- used branch CI for PR validation only
- used `main` for canary/prod deploy flow

### Issue 6. OIDC failure on `promote` job even on `main`

Observed behavior:

- `deploy-canary` worked
- `promote` failed with OIDC assume-role denial

Cause:

- `promote` uses GitHub `environment: production`
- GitHub OIDC `sub` changes for environment jobs
- IAM trust policy allowed only branch-form `sub`, not environment-form `sub`

Fix:

Updated the IAM trust policy for `demo-eks-cluster-gha-infra-role` to allow both:

- `repo:tejupagudala/petclinic-eks-portfolio:ref:refs/heads/main`
- `repo:tejupagudala/petclinic-eks-portfolio:environment:production`

This kept the deploy path secure while allowing approved promotion jobs to assume the role.

### Issue 7. Could not manually rerun canary workflow

Cause:

- `.github/workflows/api-gateway-canary.yaml` originally had only `push` trigger

Fix:

Added:

```yaml
on:
  workflow_dispatch:
  push:
    branches: [ main ]
```

This enabled manual reruns from GitHub Actions UI.

### Issue 8. Canary banner check used the wrong URL

Observed behavior:

- checking `/` did not show `CANARY TEST BUILD`

Cause:

- the banner is in Angular fragment `scripts/fragments/welcome.html`
- `/` only serves the Angular shell `index.html`

Correct validation paths:

- browser:
  - `http://<ALB>/#!/welcome`
- raw fragment:
  - `http://<ALB>/scripts/fragments/welcome.html`

### Issue 9. Git branch/compare confusion

Observed behavior:

- GitHub compare said “There isn’t anything to compare”
- local branch history had multiple merges and CI-generated commits

Fix:

- created clean child branches
- verified actual diffs with local Git commands
- used a clean branch when needed to isolate the intended change set

## Commands That Were Useful

### Check EKS access entries

```bash
aws eks list-access-entries \
  --cluster-name demo-eks-cluster \
  --region us-east-1
```

### Check infra-role access policy

```bash
aws eks list-associated-access-policies \
  --cluster-name demo-eks-cluster \
  --principal-arn arn:aws:iam::479407618698:role/demo-eks-cluster-gha-infra-role \
  --region us-east-1
```

### Get ALB DNS from AWS

```bash
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --profile myaccount \
  --query 'LoadBalancers[?contains(LoadBalancerName, `petclini`) || contains(LoadBalancerName, `frontend`)].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}' \
  --output table
```

### Test the frontend fragment directly

```bash
curl -s "http://<ALB>/scripts/fragments/welcome.html?t=$(date +%s)"
```

### Test the Angular welcome page in browser

```text
http://<ALB>/#!/welcome
```

## What “Success” Looked Like

We considered the canary deployment successful when:

1. `api-gateway-ci` built and pushed a new image
2. `deploy.yaml` was updated with the new image tag
3. merge to `main` triggered `api-gateway-canary`
4. rollout paused at 20%
5. the app was reachable through the same ALB
6. after approval, the promoted version became live
7. the visible `CANARY TEST BUILD` change appeared in the app

## Current Operational Notes

- Use the same ALB for stable, canary, and promoted traffic.
- Test path-based routing with the ALB hostname directly.
- Use GitHub Actions runner logs for rollout inspection if local `kubectl` is not authorized.
- Keep GitHub `production` environment protection enabled.
- Keep IAM trust policy aligned with both:
  - `main` branch deploy job
  - `production` environment promotion job

## Recommended Next Step

The next validation to add is a full rollback test:

1. make another small visible `api-gateway` UI change
2. let canary pause at 20%
3. reject approval or force rollback
4. verify the app returns to the previous visible version

That completes the promote and rollback story for the canary implementation.
