# Phase 7 — AIOps Foundation (EKS Access + CloudWatch Observability) — COMPLETE REFERENCE

**Window:** Apr–May 2026 (~2-3 days)
**Status:** ✅ In Progress — Q1 (7.5) + Q2 (8.0) locked; Q3-Q5 pending
**The point:** Plumbing layer that makes Phase 8's AIOps Service possible

---

## 📑 Table of Contents

1. [Phase 7 Vocabulary](#vocabulary)
2. [The Two Problems This Phase Solves](#problems)
3. [EKS Access Entries — Deep Dive](#access-entries)
4. [EKS Pod Identity — Deep Dive (the new pod auth)](#pod-identity)
5. [Amazon CloudWatch Observability Add-on — Deep Dive](#cloudwatch-observability)
6. [Code Walkthrough](#code-walkthrough)
7. [The Wire-Up Diagram](#wire-up)
8. [Foundation Concepts](#foundation-concepts)
9. [5 Hostile Q&A (Drilled — Summaries)](#hostile-qa)
10. [Power Phrases & Common Mistakes](#power-phrases)
11. [Cheat Card](#cheat-card)

---

<a name="vocabulary"></a>
## 1. Phase 7 Vocabulary

### EKS Access Entries

| Term | Definition |
|---|---|
| **EKS Access Entry** | Native AWS resource mapping an IAM principal into EKS — replaces aws-auth ConfigMap |
| **`aws_eks_access_entry`** | Terraform resource declaring the principal mapping |
| **`aws_eks_access_policy_association`** | Terraform resource attaching a permission policy |
| **Access Entry type `STANDARD`** | For human IAM users/roles (vs FARGATE_LINUX, EC2_LINUX, EC2_WINDOWS) |
| **Access scope `cluster`** | Cluster-wide permissions |
| **Access scope `namespace`** | Scoped to specific namespaces (least privilege) |
| **`AmazonEKSClusterAdminPolicy`** | AWS-managed K8s cluster-admin equivalent |
| **`AmazonEKSAdminPolicy`** | Namespace admin |
| **`AmazonEKSEditPolicy`** | Namespace edit (no secrets/RBAC) |
| **`AmazonEKSViewPolicy`** | Namespace read-only |
| **`authenticationMode`** | Cluster config: `CONFIG_MAP`, `API_AND_CONFIG_MAP`, `API` |

### EKS Pod Identity

| Term | Definition |
|---|---|
| **EKS Pod Identity** | New pod-to-IAM auth (2023+) — replaces IRSA for new workloads |
| **`eks-pod-identity-agent` add-on** | DaemonSet that injects AWS creds into pods |
| **`pod_identity_association`** | Block in `aws_eks_addon` linking K8s SA to IAM role |
| **`aws_eks_pod_identity_association`** | Standalone Terraform resource for SA-to-role mapping |
| **`pods.eks.amazonaws.com`** | Service principal in trust policy for Pod Identity |
| **`sts:TagSession`** | Required STS action for Pod Identity — passes SA name as session tag |
| **`AssumeRoleForPodIdentity`** | EKS Auth API call that Pod Identity Agent uses |
| **`aws:RequestTag/kubernetes-service-account`** | IAM condition key for restricting access by SA |

### IRSA (for comparison)

| Term | Definition |
|---|---|
| **IRSA** | IAM Roles for Service Accounts (2019) — OIDC-based pod auth |
| **OIDC issuer URL** | Per-cluster URL exposed by EKS for OIDC federation |
| **`aws_iam_openid_connect_provider`** | Terraform resource registering the OIDC provider in IAM |
| **`sts:AssumeRoleWithWebIdentity`** | STS API call for IRSA token validation |
| **`eks.amazonaws.com/role-arn` annotation** | K8s ServiceAccount annotation binding to IAM role |
| **Projected ServiceAccount token** | Pod's auth token; auto-rotated, OIDC-signed |

### CloudWatch Observability

| Term | Definition |
|---|---|
| **`amazon-cloudwatch-observability` add-on** | Managed EKS add-on installing CW Agent + Fluent Bit |
| **CloudWatch Agent** | DaemonSet shipping pod/node metrics to Container Insights |
| **Fluent Bit** | DaemonSet shipping container logs to CloudWatch Logs |
| **Container Insights** | CloudWatch feature for K8s-aware pod/node metrics |
| **`amazon-cloudwatch` namespace** | Where the add-on installs its DaemonSets |
| **`CloudWatchAgentServerPolicy`** | AWS-managed IAM policy with perms CW Agent + Fluent Bit need |
| **`/aws/containerinsights/<cluster>/application`** | Log group for application container logs |
| **`/aws/containerinsights/<cluster>/dataplane`** | Log group for kubelet/runtime logs |
| **`/aws/containerinsights/<cluster>/host`** | Log group for node-level system logs |
| **CloudWatch Logs Insights** | Query language for searching log groups |

---

<a name="problems"></a>
## 2. The Two Problems This Phase Solves

### Problem 1: IAM Principals Need Cluster Access

After Phase 6, only the bootstrap runner could `kubectl` against the cluster. You needed:
- **Personal IAM roles** for debugging from your laptop
- **Cost-ops workflows** (`non-prod-stop.yaml`, `non-prod-start.yaml`) operating the cluster
- **Future AIOps Service IAM role** (Phase 8) querying cluster state

**Old way (aws-auth ConfigMap, pre-2023):**
- Edited YAML in `kube-system` namespace
- Manual mapping of IAM role ARN → K8s RBAC group like `system:masters`
- No CloudTrail visibility; single typo = full lockout

**New way (Access Entries, 2023+):**
- Two-resource Terraform model — native AWS API
- AWS-managed access policies replace handwritten RBAC
- CloudTrail logs every change
- Scopable to namespace (least privilege)

### Problem 2: Cluster Data Isn't in CloudWatch

Phase 4's Prometheus/Grafana captured in-cluster metrics for engineers. But:
- Container logs disappeared when pods died
- AWS-native tools (CloudWatch Alarms, EventBridge, AWS SDK) couldn't query cluster data
- AIOps Service needed structured AWS-side access to logs/metrics

**The fix:** `amazon-cloudwatch-observability` EKS add-on installs:
- CloudWatch Agent (DaemonSet) → metrics to Container Insights
- Fluent Bit (DaemonSet) → logs to CloudWatch Logs (3 log groups)

Both auth via EKS Pod Identity (not IRSA).

---

<a name="access-entries"></a>
## 3. EKS Access Entries — Deep Dive

### The 2-Resource Model

| Resource | Role |
|---|---|
| `aws_eks_access_entry` | Declares "this IAM principal is known to the cluster" |
| `aws_eks_access_policy_association` | Declares "this principal has THIS permission level over THIS scope" |

**Both required.** Entry alone grants nothing.

### Your Two Patterns

**Pattern 1 — Admin Roles (for_each over var list):**
```hcl
resource "aws_eks_access_entry" "admin_roles" {
  for_each      = toset(var.aws_auth_role_arns)
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin_roles" {
  for_each      = toset(var.aws_auth_role_arns)
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}
```

**Pattern 2 — Single Dedicated Role (cost-ops):**
```hcl
resource "aws_eks_access_entry" "github_actions_cost_ops" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions_cost_ops.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions_cost_ops" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions_cost_ops.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}
```

### Production Least-Privilege Mapping

| Principal | Policy | Scope |
|---|---|---|
| Human admin (incident response) | AmazonEKSAdminPolicy | petclinic ns |
| AIOps Service (Phase 8) | AmazonEKSViewPolicy | petclinic + amazon-cloudwatch ns |
| Cost-ops automation | Custom (nodegroup scale only) | cluster (limited actions) |
| Developer roles | AmazonEKSEditPolicy | petclinic ns |

### The Bootstrap Fix Story (commit `0a36aa8`)

- Second bootstrap run → Terraform tries CREATE on existing Access Entry → `EntityAlreadyExistsException`
- Fix: `terraform import` + for_each idempotency pattern
- **Same class of bug as Phase 1's OIDC provider** — both cold-start vs warm-start surface only

---

<a name="pod-identity"></a>
## 4. EKS Pod Identity — Deep Dive

### Why a New Mechanism

**IRSA pain (2019):**
- Complex trust policies embedding OIDC issuer URL
- Cluster-specific (not portable)
- OIDC provider creation is one-time-per-account dance (Phase 1 pain)
- Trust policy edits required for new SAs

**Pod Identity (2023):**
- No OIDC needed in IAM
- Simple service-principal trust: `pods.eks.amazonaws.com`
- SA-to-role mapping at EKS level (not IAM)
- Pod Identity Agent DaemonSet handles cred injection
- Cross-cluster portable

### The Request Flow

```
[Pod uses SA "cloudwatch-agent"]
       │ AWS SDK call (e.g. PutMetricData)
       ▼
[Pod Identity Agent on same node]
       │ intercepts, looks up SA → role mapping
       ▼
[EKS Auth API: AssumeRoleForPodIdentity]
       │ returns temp AWS creds
       ▼
[Pod SDK uses creds to call AWS API]
```

### Setup (your CloudWatch example)

**Step 1: Install Pod Identity Agent add-on**
```hcl
resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name = module.eks.cluster_name
  addon_name   = "eks-pod-identity-agent"
}
```

**Step 2: IAM role with Pod Identity trust**
```hcl
resource "aws_iam_role" "cloudwatch_observability_pod_identity" {
  assume_role_policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action = ["sts:AssumeRole", "sts:TagSession"]
      Condition = {
        StringEquals = {
          "aws:RequestTag/kubernetes-service-account" = "cloudwatch-agent"
        }
      }
    }]
  })
}
```

**Step 3: Attach AWS-managed permission policy**
```hcl
resource "aws_iam_role_policy_attachment" "cloudwatch_observability_agent" {
  role       = aws_iam_role.cloudwatch_observability_pod_identity.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
```

**Step 4: Bind SA to role via add-on**
```hcl
resource "aws_eks_addon" "cloudwatch_observability" {
  addon_name = "amazon-cloudwatch-observability"
  pod_identity_association {
    service_account = "cloudwatch-agent"
    role_arn        = aws_iam_role.cloudwatch_observability_pod_identity.arn
  }
}
```

### IRSA vs Pod Identity — Side-by-Side

| Axis | IRSA | Pod Identity |
|---|---|---|
| Cluster prereq | Create IAM OIDC Provider | Install eks-pod-identity-agent add-on |
| Trust principal | OIDC provider ARN + sub condition | `pods.eks.amazonaws.com` |
| SA binding | Annotation on K8s SA | `pod_identity_association` block |
| Cross-cluster portable? | No (OIDC issuer cluster-specific) | Yes |
| Cred injection | Mutating webhook + projected token | Pod Identity Agent DaemonSet |
| STS API | `sts:AssumeRoleWithWebIdentity` | `AssumeRoleForPodIdentity` (EKS Auth) |
| Required actions | `sts:AssumeRole` | `sts:AssumeRole` + `sts:TagSession` |
| When to use | Existing clusters, IRSA-documented Helm charts | New clusters, AWS-managed add-ons |

### Your Project's Hybrid Usage (Senior Signal)

- **IRSA:** AWS Load Balancer Controller (Phase 3 — older Helm chart)
- **Pod Identity:** CloudWatch Observability (Phase 7 — newer AWS add-on)
- **Why both:** chose based on the add-on's age and AWS's recommended pattern

---

<a name="cloudwatch-observability"></a>
## 5. Amazon CloudWatch Observability Add-on — Deep Dive

### What Gets Installed

| Component | Type | Purpose |
|---|---|---|
| `cloudwatch-agent` | DaemonSet | One per node — ships metrics to Container Insights |
| `fluent-bit` | DaemonSet | One per node — ships container logs to CloudWatch Logs |
| `cloudwatch-agent` | ServiceAccount | Used by both DaemonSets; gets Pod Identity creds |
| `amazon-cloudwatch` | Namespace | Where everything lives |
| Various ConfigMaps | ConfigMap | Default configs for agent + fluent-bit |

### CloudWatch Agent

- Scrapes pods on local node via Kubelet API
- Pod-level: `pod_cpu_utilization`, `pod_memory_utilization`, `pod_network_rx_bytes`
- Node-level: `node_cpu_utilization`, `node_filesystem_utilization`
- Ships to **CloudWatch Container Insights** namespace `ContainerInsights`

### Fluent Bit

- Tails `/var/log/containers/*.log` on each node
- Enriches with K8s metadata (namespace, pod name, container name, labels)
- Ships to **3 log groups:**
  - `/aws/containerinsights/<cluster>/application` — your Petclinic logs
  - `/aws/containerinsights/<cluster>/dataplane` — kubelet, container runtime
  - `/aws/containerinsights/<cluster>/host` — node OS logs

### Why an EKS Add-on (vs Manual Helm Chart)

**Add-on wins:**
- AWS manages upgrades — single version field bump
- AWS handles K8s compatibility matrices
- IAM integration via `pod_identity_association` — no manual SA annotation
- CloudWatch dashboards auto-created
- Less YAML to maintain

**Manual Helm wins:**
- More config flexibility
- Pin specific versions
- Works on non-EKS

For your portfolio: add-on is the right call — managed lifecycle for free.

### The Bootstrap Verification Step

Your `infra-bootstrap.yaml` lines 195-227 verify add-ons are healthy:
1. `aws eks list-addons` — lists all
2. `aws eks describe-addon --addon-name eks-pod-identity-agent`
3. `aws eks describe-addon --addon-name amazon-cloudwatch-observability`
4. `kubectl get pods -n kube-system | grep eks-pod-identity-agent`
5. `kubectl get pods -n amazon-cloudwatch`

Readiness gate before downstream observability-dependent steps run.

---

<a name="code-walkthrough"></a>
## 6. Code Walkthrough

### File 1: `terraform/main.tf` (lines 118-160) — Access Entries

```hcl
# Pattern 1: for_each over admin roles list
resource "aws_eks_access_entry" "admin_roles" {
  for_each      = toset(var.aws_auth_role_arns)
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  type          = "STANDARD"
  depends_on    = [module.eks]
}

resource "aws_eks_access_policy_association" "admin_roles" {
  for_each      = toset(var.aws_auth_role_arns)
  cluster_name  = module.eks.cluster_name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
  depends_on    = [aws_eks_access_entry.admin_roles]
}

# Pattern 2: single dedicated role for cost-ops automation
resource "aws_eks_access_entry" "github_actions_cost_ops" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions_cost_ops.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_actions_cost_ops" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.github_actions_cost_ops.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}
```

### File 2: `terraform/cloudwatch_observability.tf` — Pod Identity + Add-on

```hcl
# IAM role with Pod Identity trust + SA condition
resource "aws_iam_role" "cloudwatch_observability_pod_identity" {
  assume_role_policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }   # ⭐ Pod Identity principal
      Action = ["sts:AssumeRole", "sts:TagSession"]         # ⭐ TagSession required
      Condition = {
        StringEquals = {
          "aws:RequestTag/kubernetes-service-account" = "cloudwatch-agent"
        }
      }
    }]
  })
}

# AWS-managed permission policy
resource "aws_iam_role_policy_attachment" "cloudwatch_observability_agent" {
  role       = aws_iam_role.cloudwatch_observability_pod_identity.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Pod Identity Agent add-on (the cred injection DaemonSet)
resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name      = module.eks.cluster_name
  addon_name        = "eks-pod-identity-agent"
}

# CloudWatch Observability add-on with SA-to-role binding
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name = module.eks.cluster_name
  addon_name   = "amazon-cloudwatch-observability"

  pod_identity_association {
    service_account = "cloudwatch-agent"
    role_arn        = aws_iam_role.cloudwatch_observability_pod_identity.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.cloudwatch_observability_agent,
    aws_eks_addon.eks_pod_identity_agent
  ]
}
```

### File 3: Bootstrap verification step (`infra-bootstrap.yaml` lines 195-227)

```yaml
- name: Verify CloudWatch observability add-ons
  run: |
    CLUSTER_NAME=$(terraform -chdir=terraform output -raw cluster_name)
    aws eks list-addons --cluster-name "$CLUSTER_NAME"
    aws eks describe-addon --addon-name eks-pod-identity-agent --cluster-name "$CLUSTER_NAME"
    aws eks describe-addon --addon-name amazon-cloudwatch-observability --cluster-name "$CLUSTER_NAME"
    kubectl get pods -n kube-system | grep eks-pod-identity-agent || true
    kubectl get pods -n amazon-cloudwatch || true
```

---

<a name="wire-up"></a>
## 7. The Wire-Up Diagram

```
                  ┌────────────────────────────────┐
                  │   Terraform aws_eks_addon      │
                  │   "cloudwatch_observability"   │
                  └──────────────┬─────────────────┘
                                 │ installs
                                 ▼
┌──────────────────────────────────────────────────────────┐
│ Namespace: amazon-cloudwatch                              │
│                                                            │
│  ┌──────────────────┐         ┌──────────────────┐        │
│  │ cloudwatch-agent │         │ fluent-bit       │        │
│  │ DaemonSet        │         │ DaemonSet        │        │
│  │ (one per node)   │         │ (one per node)   │        │
│  └────────┬─────────┘         └────────┬─────────┘        │
│           │                            │                   │
│           │ uses SA "cloudwatch-agent" │                   │
│           └─────────────┬──────────────┘                   │
└─────────────────────────┼──────────────────────────────────┘
                          │ AWS SDK call
                          ▼
            ┌─────────────────────────────┐
            │ EKS Pod Identity Agent      │
            │ (DaemonSet in kube-system)  │
            │ intercepts → looks up SA →  │
            │ AssumeRoleForPodIdentity    │
            └─────────────┬───────────────┘
                          │
                          ▼
            ┌─────────────────────────────┐
            │ IAM role:                   │
            │ cloudwatch_observability    │
            │ _pod_identity               │
            │ + CloudWatchAgentServerPolicy│
            └────────────┬────────────────┘
                         │
            ┌────────────┴────────────────┐
            ▼                              ▼
  ┌──────────────────┐         ┌────────────────────────┐
  │ CW Container     │         │ CloudWatch Logs        │
  │ Insights metrics │         │ /aws/containerinsights/│
  └──────────────────┘         │  <cluster>/application │
                               │  <cluster>/dataplane   │
                               │  <cluster>/host        │
                               └────────────────────────┘
                                          │
                                          │ Phase 8 AIOps Service queries
                                          ▼
                              ┌────────────────────────┐
                              │ Logs Insights /        │
                              │ GetMetricData          │
                              └────────────────────────┘
```

---

<a name="foundation-concepts"></a>
## 8. Foundation Concepts

- **Access Entries replace aws-auth ConfigMap** — native AWS API, CloudTrail visibility, scopable
- **Two-resource Access Entry model** — Entry + Policy Association (both required)
- **AWS-managed access policies** — ClusterAdmin / Admin / Edit / View / AdminView
- **Pod Identity replaces IRSA for new workloads** — no OIDC, universal trust principal
- **`pods.eks.amazonaws.com`** — Pod Identity service principal
- **`sts:TagSession`** — required action; passes SA name as session tag
- **`aws:RequestTag/kubernetes-service-account`** — IAM condition for SA-based access control
- **Hybrid IRSA + Pod Identity** — both can coexist; choose per workload
- **EKS add-on model** — AWS manages CloudWatch Agent + Fluent Bit lifecycle
- **Container Insights** — CloudWatch's K8s-aware metrics feature
- **3 log groups** — application / dataplane / host
- **Bootstrap idempotency** — `EntityAlreadyExistsException` class of bug surfaces only on re-runs

---

<a name="hostile-qa"></a>
## 9. 5 Hostile Q&A (Drilled — Summaries)

Full Q&As with ideal answers, memory tips, follow-ups live in **[phase-7-qa.md](phase-7-qa.md)**.

| Q | Question | Score | Key insight |
|---|----------|-------|-------------|
| **Q1** | Access Entries vs aws-auth ConfigMap | **7.5** | 2-resource model; CloudTrail traceability; least-privilege gap acknowledged |
| **Q2** | Pod Identity vs IRSA | **8.0** | OIDC vs service principal; cross-cluster portability; hybrid usage in your project |
| **Q3** | CloudWatch metrics + logs flow | pending | DaemonSets; 3 log groups; Pod Identity wiring |
| **Q4** | Why EKS add-on vs self-managed | pending | Managed lifecycle; auto-IAM integration; cost = $0 |
| **Q5** | Phase 7's role in AIOps | pending | Data plumbing for Phase 8; without it, AIOps can't query |

---

<a name="power-phrases"></a>
## 10. Power Phrases & Common Mistakes

### Power Phrases

**Access Entries:**
- *"AWS deprecated aws-auth in 2023 for Access Entries"*
- *"Native AWS API → CloudTrail logs every change"*
- *"Two-resource model — Entry plus Policy Association"*
- *"AWS-managed policies replace handwritten RBAC"*
- *"Production fix: namespace-scoped policies per principal"*

**Pod Identity:**
- *"IRSA via OIDC federation; Pod Identity via native EKS auth API"*
- *"`sts:AssumeRoleWithWebIdentity` (IRSA) vs `AssumeRoleForPodIdentity` (Pod Identity)"*
- *"`pods.eks.amazonaws.com` is universal — IRSA OIDC is cluster-specific"*
- *"My ALB Controller uses IRSA; CloudWatch uses Pod Identity"*
- *"`sts:TagSession` required — passes SA name as session tag"*

**CloudWatch Observability:**
- *"One add-on, two DaemonSets — Agent for metrics, Fluent Bit for logs"*
- *"Three log groups: application, dataplane, host"*
- *"Managed add-on means AWS handles upgrades and K8s compatibility"*

### Common Mistakes

- ❌ Saying "I edited aws-auth ConfigMap" — your code uses Access Entries
- ❌ Confusing IRSA with Pod Identity
- ❌ Saying "I installed CW Agent via Helm" — it's an EKS add-on
- ❌ Forgetting the two-resource Access Entry model
- ❌ Naming wrong service principal (`eks.amazonaws.com` instead of `pods.eks.amazonaws.com`)
- ❌ Saying Fluent Bit ships metrics (it ships LOGS only)
- ❌ Forgetting `sts:TagSession` in Pod Identity trust
- ❌ Saying one log group (there are 3: application/dataplane/host)
- ❌ Saying Pod Identity deprecates IRSA (they coexist)

---

<a name="cheat-card"></a>
## 11. Cheat Card (One-Page Summary)

### Phase 7 in 30 Seconds
Phase 7 = data plumbing for Phase 8. Two problems solved:
1. **IAM principals need cluster access** → migrated aws-auth → Access Entries (native API, CloudTrail visible)
2. **Cluster data needs to be in CloudWatch** → installed `amazon-cloudwatch-observability` add-on (Agent + Fluent Bit DaemonSets, Pod Identity auth)

### The 2 Access Entry Resources
| Resource | Purpose |
|---|---|
| `aws_eks_access_entry` | Declare principal |
| `aws_eks_access_policy_association` | Attach permission |

### The 5 AWS-Managed Access Policies
ClusterAdmin / Admin / Edit / View / AdminView

### The 4 Pod Identity Setup Steps
1. Install `eks-pod-identity-agent` add-on
2. Create IAM role with trust = `pods.eks.amazonaws.com` + `sts:AssumeRole`,`sts:TagSession`
3. Attach permission policy (e.g. `CloudWatchAgentServerPolicy`)
4. Bind SA via `pod_identity_association` block or standalone resource

### IRSA vs Pod Identity Quick Pick
| Use IRSA | Use Pod Identity |
|---|---|
| Existing cluster | New cluster |
| Older Helm charts | AWS-managed add-ons |
| Broad ecosystem support | Cross-cluster portability needed |

### CloudWatch Observability Stack
- **Namespace:** `amazon-cloudwatch`
- **DaemonSet 1:** `cloudwatch-agent` → Container Insights metrics
- **DaemonSet 2:** `fluent-bit` → 3 log groups
- **SA:** `cloudwatch-agent` (gets Pod Identity creds)
- **IAM policy:** `CloudWatchAgentServerPolicy`

### Score Targets
| Question Type | Target |
|---|---|
| Access Entries vs aws-auth | 8+ |
| Pod Identity vs IRSA | 8+ |
| CW Observability data flow | 8+ |
| Why EKS add-on | 7.5+ |
| Phase 7 role in AIOps | 8+ |

---

## Phase 7 — IN PROGRESS ⏳

**Q1 + Q2 LOCKED. Average so far: 7.75/10. Q3-Q5 remaining.**

Next: **Q3 — CloudWatch metrics + logs data flow walkthrough.**
