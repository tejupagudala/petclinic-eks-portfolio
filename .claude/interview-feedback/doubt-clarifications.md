# Phase 4 — Doubt Clarifications Reference

Quick-reference for all the clarification questions asked during Phase 4 drilling. Use this as a lookup when you forget a concept.

For deeper coverage, see:
- [`phase-4-reference.md`](phase-4-reference.md) — full story + vocabulary + cheat card
- [`phase-4-qa.md`](phase-4-qa.md) — Q&A bank with ideal answers
- [`one-liners.md`](one-liners.md) — interview one-liners

---

## 📑 Index of Doubts Asked

1. [Where do diagnostic dumps get saved?](#q1-diagnostic-dumps)
2. [What is a Kubernetes Service Account?](#q2-service-account)
3. [What is STS? What is sed?](#q3-sts-sed)
4. [What does "fresh account" mean?](#q4-fresh-account)
5. [What is OIDC (confirmation)?](#q5-oidc)
6. [What is declarative apply?](#q6-declarative-apply)
7. [Examples of imperative commands in my project?](#q7-imperative-examples)
8. [What is a cold-start path?](#q8-cold-start-path)
9. [Can my runners be non-ephemeral?](#q9-non-ephemeral-runners)
10. [Is my CI pipeline ephemeral or non-ephemeral?](#q10-ci-pipeline-ephemeral)
11. [How are GitHub-hosted runners secured on the public internet?](#q11-github-hosted-runner-security)
12. [Canary vs Blue-Green tradeoffs + what does "20% traffic" mean?](#q12-canary-vs-bluegreen)
13. [What is a webhook + caBundle?](#q13-webhook-cabundle)
14. [What's the difference between EKS Access Entries and IAM?](#q14-eks-access-entries)
15. [Why is the OIDC provider a "global resource"?](#q15-oidc-global-resource)
16. [What is `$GITHUB_ENV` and why does it matter?](#q16-github-env)
17. [What's IRSA and how is it different from a regular IAM role?](#q17-irsa)
18. [What's the e2e-smoke workflow chain?](#q18-e2e-smoke)
19. [What does `--ignore-not-found` do?](#q19-ignore-not-found)
20. [Helm vs Argo CD — do I need both?](#q20-helm-vs-argocd)

---

<a name="q1-diagnostic-dumps"></a>
## Q1: Where do diagnostic dumps get saved?

**Short answer:** In GitHub Actions workflow logs (UI). Retained for **90 days** by default.

**To find them:** GitHub repo → Actions tab → failed workflow run → click failing job → expand `Dump customers-service diagnostics on failure` step.

**To make portable:** Add `actions/upload-artifact@v4` step to save dumps as downloadable ZIP files.

**Production-grade:** Ship to S3, CloudWatch Logs, Slack, or Datadog.

---

<a name="q2-service-account"></a>
## Q2: What is a Kubernetes Service Account?

**Short answer:** A **pod identity** — like a user account but for processes inside pods.

**3 uses:**
1. Authenticate to K8s API (every pod uses one)
2. **IRSA** — annotate SA with `eks.amazonaws.com/role-arn` to assume AWS IAM role
3. RBAC scoping inside Kubernetes

**In your project:** `aws-load-balancer-controller` SA is annotated to assume the ALB IAM role.

**Interview one-liner:** *"A K8s ServiceAccount is a pod identity. With an `eks.amazonaws.com/role-arn` annotation, the SA enables IRSA — pods using that SA can assume the specified AWS IAM role via OIDC federation. No static AWS keys needed."*

---

<a name="q3-sts-sed"></a>
## Q3: What is STS? What is sed?

**STS = AWS Security Token Service.** Issues temporary credentials. Default 1-hour lifetime. Your OIDC + IRSA flows both use `sts:AssumeRoleWithWebIdentity`.

**sed = Unix stream editor.** Find-and-replace in files. Pattern: `sed -i "s|old|new|g" filename`. Your CI uses it to swap the image tag in `deploy.yaml`.

Used `|` instead of `/` as delimiter because tags contain `/`.

---

<a name="q4-fresh-account"></a>
## Q4: What does "fresh account" mean?

**Short answer:** An AWS account where the OIDC Identity Provider has **never been created.**

| Scenario | Variable | Count | Result |
|---|---|---|---|
| Fresh account | `""` (empty) | 1 | Terraform creates the OIDC provider |
| Already-set-up account | Existing ARN | 0 | Terraform skips creation, reuses existing |

**Your real scenario (March 22 — commits `aab7a3a`, `2a9d93b`):** You hit `EntityAlreadyExistsException` because the OIDC provider already existed (from earlier Terraform runs). Fix: conditional create pattern.

---

<a name="q5-oidc"></a>
## Q5: What is OIDC (confirmation)?

**Short answer:** **OpenID Connect** — protocol for one system to trust another system's identity claims.

**In your project:**
- **GitHub Actions** is an OIDC Provider (issues identity tokens for workflows)
- **EKS** is an OIDC Provider (issues identity tokens for pods)
- **AWS IAM** has a "trusted providers" list — registers both as trusted

**Direction:** GitHub Actions / pods → call AWS APIs. OIDC is how they prove identity.

**Interview one-liner:** *"OIDC is identity federation. My GitHub Actions workflows need to call AWS APIs. AWS accepts GitHub's JWT tokens because I registered GitHub as a trusted OIDC Provider in AWS IAM. AWS verifies the token signature, returns short-lived STS credentials. No static AWS keys needed."*

---

<a name="q6-declarative-apply"></a>
## Q6: What is declarative apply?

**Short answer:** You describe **WHAT** the desired state should be. System figures out **HOW** to get there.

**Vs imperative:** You give step-by-step instructions (`kubectl create`, `kubectl set image`, `kubectl scale`).

**In your project:** `kubectl apply -f deploy.yaml`, `terraform apply`, `helm upgrade --install` are all declarative.

**Behavior on re-run:**
- Resource doesn't exist → creates
- Resource exists, identical → no-op
- Resource exists, differs → patches to match

**Why it matters:** Declarative = **idempotent by design.** Safe to re-run.

---

<a name="q7-imperative-examples"></a>
## Q7: Examples of imperative commands in my project?

| Command | File | Why imperative |
|---|---|---|
| `aws eks update-nodegroup-config` | non-prod-stop.yaml | One-time action, not state declaration |
| `helm uninstall` | infra-bootstrap.yaml | Recovery action |
| `kubectl replace --raw /finalize` | infra-bootstrap.yaml | Force-finalize stuck namespace |
| `aws ec2 stop-instances` | non-prod-stop.yaml | One-time action |
| `sed -i` | ci.yaml | File modification |

**When imperative is RIGHT:** one-time recovery, temporary changes, reading data, forcing rare cleanup.

**Your pattern:** Declarative for state convergence; imperative for exceptional recovery.

---

<a name="q8-cold-start-path"></a>
## Q8: What is a cold-start path?

**Short answer:** Bringing up a system from **zero state** — nothing exists yet.

**vs Warm-start:** System is already running; you're making changes.

**Why hard:** Every chicken-and-egg, every race condition, every "I assumed X existed" surfaces simultaneously because **nothing exists yet to lean on.**

**Why March 22 was a marathon:** You were running bootstrap on a truly empty AWS account for the first time end-to-end. All hidden assumptions surfaced at once.

**Analogy:** Like starting a car in winter with a dead battery and no gas vs. just accelerating while already driving.

---

<a name="q9-non-ephemeral-runners"></a>
## Q9: Can my runners be non-ephemeral?

**Short answer:** Your self-hosted runner IS already non-ephemeral. EC2 stays running 24/7 (unless cost cron stops it).

| Type | Behavior |
|---|---|
| **Persistent (your setup)** | EC2 stays running, processes many jobs |
| **Ephemeral** | New runner spawned per job, destroys after |
| **JIT (Just-in-Time)** | Same as ephemeral with one-time tokens |

**Tradeoffs:**
- Persistent = faster (no boot delay), but state persists
- Ephemeral = clean state per job, but adds 1-3 min boot per job

**For your project:** Persistent is right — steady workload, jobs start in seconds.

---

<a name="q10-ci-pipeline-ephemeral"></a>
## Q10: Is my CI pipeline ephemeral or non-ephemeral?

**Short answer:** **EPHEMERAL.** Your `ci.yaml` uses `runs-on: ubuntu-latest` = GitHub-hosted runner.

**GitHub-hosted runners are always ephemeral** — fresh VM per job, destroyed after.

**Your two-tier setup:**

| Workflow | Runner type | Ephemeral? |
|---|---|---|
| `ci.yaml` | GitHub-hosted | ✅ Yes |
| `infra-bootstrap.yaml` (main job) | Self-hosted EC2 | ❌ No (persistent) |
| `e2e-smoke.yaml` | Self-hosted | ❌ No |
| `non-prod-stop.yaml`, etc. | GitHub-hosted | ✅ Yes |
| `infra-destroy.yaml` | GitHub-hosted | ✅ Yes |

**Pattern:** Ephemeral for build/test/scan (public network OK); persistent for kubectl against private EKS.

---

<a name="q11-github-hosted-runner-security"></a>
## Q11: How are GitHub-hosted runners secured on the public internet?

**5 security layers:**

1. **Ephemeral VMs** — destroyed after each job, no state persistence
2. **OIDC federation for AWS** — 1-hour STS credentials, scoped to your repo+branch via trust policy
3. **GitHub Secrets** — encrypted at rest with libsodium, auto-redacted from logs
4. **Scoped tokens, not passwords** — DockerHub access token (revocable), SonarCloud API token
5. **Network topology** — outbound-only, no inbound network access, all TLS

**Combined effect:** Compromise window = single job's runtime (~5-10 min), not permanent access.

**Interview one-liner:** *"Five layers: ephemeral VMs destroyed per job, OIDC giving 1-hour STS credentials instead of long-lived keys, secrets encrypted and auto-redacted, scoped revocable tokens, outbound-only TLS network. Public internet ≠ insecure — defenses are in identity + token lifetime."*

---

<a name="q12-canary-vs-bluegreen"></a>
## Q12: Canary vs Blue-Green tradeoffs + what does "20% traffic" mean?

**Canary vs Blue-Green:**

| | Canary | Blue-Green |
|---|---|---|
| **Infra cost** | Same node footprint | Doubles during deployment |
| **Rollout** | Gradual (20% → 50% → 100%) | Instant switch |
| **Rollback** | Shift traffic back (seconds) | Flip switch (instant) |
| **Risk detection** | Catches at 20% — limits blast radius | All-or-nothing |
| **DB migrations** | Harder (both share DB) | Easier (Green tested isolated) |

**Why you chose canary:** $20/mo budget can't afford doubled infra. Blast-radius control matters.

**"20% traffic" means:** 20% of REQUESTS (not users, not code changes) routed to canary pods. ALL code goes to canary; only TRAFFIC is split. Distribution is random at the request level.

**Interview one-liner:** *"20% of requests, not users. ALL code changes go to the canary pods; only the traffic split is 20/80. A single user might hit both versions in one session. For UI consistency you'd add sticky routing; for stateless APIs like mine, request-level splitting is fine."*

---

<a name="q13-webhook-cabundle"></a>
## Q13: What is a webhook + caBundle?

**Admission webhook** = Kubernetes extensibility point. Code that runs BEFORE resources are stored (validates or mutates them).

**ALB Controller's two webhooks:**
- **MutatingWebhookConfiguration** — modifies Ingress/Service during admission
- **ValidatingWebhookConfiguration** — rejects invalid configs

**caBundle** = the Certificate Authority bundle the K8s API server uses to verify the webhook's TLS cert. Must MATCH the cert stored in `aws-load-balancer-tls` Secret.

**If mismatched:** Every kubectl apply fails with TLS verification errors. Cluster "effectively locked."

**Your fix:** dry-run detection → nuke and reinstall fresh.

---

<a name="q14-eks-access-entries"></a>
## Q14: What's the difference between EKS Access Entries and IAM?

**IAM** = AWS-layer authorization. "Is this caller a valid AWS identity?"
**EKS Access Entries** = K8s-layer authorization. "Does this IAM role have permission to call the K8s API?"

**You need BOTH.** Having a valid IAM role doesn't grant Kubernetes access — you must explicitly add the role to EKS Access Entries with appropriate policy (e.g., `AmazonEKSClusterAdminPolicy`).

**Replaces:** The old `aws-auth` ConfigMap pattern.

**Your fix (commit `a2beae8`):** Added Terraform resources to grant CI role cluster admin.

---

<a name="q15-oidc-global-resource"></a>
## Q15: Why is the OIDC provider a "global resource"?

**Short answer:** AWS allows **only ONE OIDC Identity Provider per account per URL.**

Multiple Terraform stacks can't each create their own provider for `token.actions.githubusercontent.com` — they'd conflict.

**Solution pattern (universal for global AWS resources):**
```hcl
resource "aws_X" "Y" {
  count = var.existing_X_arn == "" ? 1 : 0
}

locals {
  X_arn = var.existing_X_arn != "" ? var.existing_X_arn : aws_X.Y[0].arn
}
```

**Other AWS resources that are global per account:**
- IAM users
- KMS aliases
- Route53 hosted zones (for same domain)
- IAM OIDC providers

---

<a name="q16-github-env"></a>
## Q16: What is `$GITHUB_ENV` and why does it matter?

**Short answer:** A special file in GitHub Actions where env vars persist across steps.

Each step in a job gets a fresh shell. Env vars set in step 1 are gone in step 2. EXCEPT for vars exported to `$GITHUB_ENV`:

```bash
echo "KUBECONFIG=$RUNNER_TEMP/kubeconfig" >> "$GITHUB_ENV"
```

**Why it matters in your project:** Kubeconfig set in "Configure kubeconfig" step is automatically available to all subsequent steps without re-running `aws eks update-kubeconfig` each time.

---

<a name="q17-irsa"></a>
## Q17: What's IRSA and how is it different from a regular IAM role?

**IRSA = IAM Roles for Service Accounts.**

**Regular IAM role:** Assumed by AWS services (EC2, Lambda) or human users.

**IRSA:** Assumed by **Kubernetes pods** via:
1. K8s ServiceAccount has annotation `eks.amazonaws.com/role-arn`
2. Pod uses that SA
3. Pod gets a projected token (signed by EKS OIDC issuer)
4. Pod calls AWS STS with the token → gets AWS credentials

**Why it matters:** Pods can call AWS APIs (S3, DynamoDB) **without static keys baked into the image.** Pod-specific permissions, short-lived credentials.

**Your project:** ALB Controller pod uses IRSA to call AWS APIs and create Load Balancers.

---

<a name="q18-e2e-smoke"></a>
## Q18: What's the e2e-smoke workflow chain?

**Short answer:** Auto-triggered AFTER `infra-bootstrap.yaml` completes successfully.

```yaml
# .github/workflows/e2e-smoke.yaml
on:
  workflow_run:
    workflows: ["infra-bootstrap"]
    types: [completed]

jobs:
  smoke:
    if: github.event.workflow_run.conclusion == 'success'
```

**What it does:** Makes 3 curl calls against your ALB endpoint to validate end-to-end:
- `/api/customer/owners`
- `/api/vet/vets`
- `/api/visit/owners/1/pets/1/visits`

**Each curl validates:** DNS → ALB → Ingress → api-gateway → backend service → RDS.

**8 things validated with 3 calls.** Catches "is this actually working?" — turns "I deployed" into "I deployed AND it works."

---

<a name="q19-ignore-not-found"></a>
## Q19: What does `--ignore-not-found` do?

**Short answer:** Makes kubectl delete commands **idempotent** — no error if the resource is already gone.

```bash
kubectl delete mutatingwebhookconfiguration aws-load-balancer-webhook --ignore-not-found
```

**Why it matters:** In your ALB webhook recovery cascade, you delete 5+ things sequentially. Without `--ignore-not-found`, if any one is already missing (from previous partial cleanup), the entire cascade fails.

**Pattern:** *"Try to clean up X. If X doesn't exist, that's fine — it's already gone."*

---

<a name="q20-helm-vs-argocd"></a>
## Q20: Helm vs Argo CD — do I need both?

**Short answer:** YES. They solve different layers.

| Layer | Tool | Job |
|---|---|---|
| **Packaging** | Helm | Bundle complex K8s apps into reusable charts |
| **Orchestration** | Argo CD | Manage Helm releases declaratively from git |

**They work TOGETHER.** Argo CD calls `helm template` and `helm install` under the hood.

**Your current state:** Argo CD installed but NOT actively managing apps. 2 Application manifests in `kubernetes/argocd/` exist but aren't applied. **Mid-migration state** — fine for portfolio, honest framing wins in interviews.

**Pattern:** Helm for third-party platform tools, plain manifests for your own simple apps, Argo CD orchestrating both.

---

## 🎯 How to Use This Doc

| Scenario | Action |
|---|---|
| **Studying for interview** | Read top to bottom (~15 min) |
| **Forgot a concept mid-prep** | Use Index to jump to specific Q |
| **Adding new doubts** | Append to this file as you encounter them |
| **Cross-reference** | Each entry links back to deeper coverage in `phase-4-reference.md`, `phase-4-qa.md`, or `one-liners.md` |

---

## 🔄 This is a living document

Add new doubts as you encounter them. Format:
```markdown
## Qxx: [your question]

**Short answer:** [the key concept]

**Details:** [optional deeper explanation]

**Interview one-liner:** [if applicable]
```
