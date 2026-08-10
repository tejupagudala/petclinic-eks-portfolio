# Phase 2 — Cost Discipline & Quality Gates (COMPLETE REFERENCE)

**Window:** Mar 12 → Mar 15, 2026 (~4 days of intense work)
**Final Average Score:** 7.7/10 across 5 hostile interview questions
**Status:** ✅ Locked — interview-viable

This is your **complete reference** for Phase 2. Everything covered in training is captured here.

---

## 📑 Table of Contents

1. [The Story (Why / What / Fails / Wins)](#the-story)
2. [Architecture Decisions Explained](#architecture-decisions)
3. [The 4 Tracks of Work](#the-4-tracks)
4. [cost_guardrails.tf Complete Walkthrough](#cost-guardrails-walkthrough)
5. [Foundation Concepts](#foundation-concepts)
6. [5 Hostile Interview Q&A (Drilled)](#hostile-qa)
7. [Follow-Up Q&A](#followup-qa)
8. [Power Phrases & Secret Weapons](#power-phrases)
9. [Common Mistakes to Avoid](#common-mistakes)
10. [Cheat Card](#cheat-card)

---

<a name="the-story"></a>
## 1. The Story (Why / What / Fails / Wins)

### Why Phase 2 Existed

After Phase 1, you had a working CI pipeline that built and shipped images. But it had **zero safety rails**:

| What Phase 1 lacked | The problem |
|---|---|
| No quality gates | Untested/ugly code could merge |
| No security scans | CVE-laden images could ship |
| No cost controls | One forgotten resource = surprise AWS bill |
| Permissive IAM | Cost-ops role had way too much power |
| Permissive pod runtime | Pods ran as root with all capabilities |

Phase 2 answered four questions simultaneously:
1. *"How do I make sure broken or insecure code never reaches production?"* → **Quality + security gates**
2. *"How do I keep my AWS bill under $20/month while learning?"* → **Cost discipline**
3. *"How do I get warned BEFORE the bill explodes?"* → **Cost governance**
4. *"How do I run pods without making my cluster attackable?"* → **Security hardening**

### The Fails (Human Story)

| Date | Commit | What broke |
|------|--------|-----------|
| Mar 14 | `4b74aa2` | "security scan fail fs" — first Trivy run found real CVEs in source |
| Mar 14 | `cfa3168` | "missed the import for the security issue fix" |
| Mar 14 | `f2521af` | "fixed the security issue for code analysis" — chasing SonarCloud issues |
| Mar 14 | `1f1c251` | "removed verify jacoco step" — JaCoCo config broke build |
| Mar 14 | `f2f98bd` | "jacoco config plugin added" (proper version) |
| Mar 15 | `fb4e26b` | "misindentation of security context block" — YAML indentation bit again |
| Mar 13 | `e00a62b` | "formatting errors for failed cron job" — first cron always has YAML issues |

**Honest interview tells:**
- *"My first Trivy scan immediately found real CVEs — I had to upgrade Spring dependencies before the pipeline would pass."*
- *"JaCoCo's first config broke the verify phase — I had to read the JaCoCo Maven plugin docs to get the goals in the right order."*
- *"My pod security context had a YAML indentation bug — runAsNonRoot was at the wrong nesting level. Pods kept starting as root. Took me an evening to spot."*

### The Wins

By Mar 15, you had:
- ✅ Full CI/CD with **blocking quality + security gates** (any HIGH/CRITICAL = no merge)
- ✅ **Nightly auto-shutdown** saving ~62% of compute spend
- ✅ **Daily cost report** in your inbox + workflow gate on excess spend
- ✅ **AWS Budgets** with KMS-encrypted SNS alerts at 50/80/100%
- ✅ **Cost Anomaly Detector** catching unusual spend patterns daily
- ✅ **Production-grade pod security context** (PSS Restricted profile)
- ✅ **Least-privilege IAM** for all cost-ops automation

**This is when your project became a real DevOps platform, not just a CI demo.**

---

<a name="architecture-decisions"></a>
## 2. Architecture Decisions Explained

### Why a 4-Layer Cost Strategy

| Layer | Component | Effect | Catches |
|---|---|---|---|
| **1. Cheap compute** | Spot t3.small | ~70% off on-demand | Baseline reduction |
| **2. Scheduled scaling** | Cron scale-to-zero | ~62% on top of spot | Off-hours waste |
| **3. Active monitoring** | Daily report → fails CI on overrun | Reactive gate | Threshold violations |
| **4. Proactive governance** | Budgets + Anomaly Detection | Pattern detection | Forecasted overruns + sub-budget drift |

**Layers 1-2 = make the bill small. Layers 3-4 = catch when something goes wrong.**

### Why AWS Budgets + Daily Report + Anomaly Detection (Defense in Depth)

These are NOT redundant — they catch different failure modes:

| Tool | Catches | Misses |
|---|---|---|
| AWS Budgets | Threshold violations ($16 at 80% forecast) | Sub-threshold anomalies |
| Daily Cost Report | Real-time CI gate, stealth drivers (NAT, ELB) | Slow drips |
| Cost Anomaly Detection | ML pattern deviations from baseline | Hard thresholds |

**Together = full cost-monitoring matrix.**

### Why Pod Security Standards Restricted Profile

The PSS Restricted profile is the **strictest tier** of Kubernetes pod security. Mapping to your project:

| Setting | Attack Prevented |
|---|---|
| `runAsNonRoot: true` | Container won't start as root |
| `runAsUser: 1000` | Forces non-root UID even if image says otherwise |
| `allowPrivilegeEscalation: false` | Blocks setuid/sudo |
| `capabilities.drop: [ALL]` | No NET_ADMIN, SYS_PTRACE, SYS_MODULE |
| `readOnlyRootFilesystem: true` | Can't drop binaries, modify configs |
| `seccompProfile: RuntimeDefault` | Blocks ~270 dangerous syscalls |

Maps to **CIS Kubernetes Benchmark sections 5.1-5.7**.

### Why Least-Privilege IAM with Three Patterns

| Pattern | When to use | Example in your code |
|---|---|---|
| **ARN scoping** | When AWS supports resource-level perms | Budgets ARNs, SNS topic ARN, EKS cluster ARN |
| **Tag-based conditions (ABAC)** | When ARNs don't scope tightly enough | EC2 Start/Stop with `ResourceTag/Role=github-self-hosted-runner` |
| **Documented exceptions** | When AWS API forces `*` | Cost Explorer `ce:GetCostAndUsage` with `trivy:ignore: AVD-AWS-0057` |

---

<a name="the-4-tracks"></a>
## 3. The 4 Tracks of Work

### Track 1: Quality Gates Added to CI (Mar 14)

**Key commits:** `015cfc5`, `680a964`, `f2f98bd`, `1f1c251`, `56aab81`, `6da4fa9`

**What landed:**
- SonarCloud integration with `qualitygate.wait=true`
- JaCoCo plugin in `app/pom.xml`
- New unit tests for api-gateway (controller/client/dto/config)
- Trivy in 3 modes (FS / K8s / Terraform) with `exit-code: 1`

This is when `ci.yaml` grew from a simple build+push workflow into the 5-job pipeline you have today.

### Track 2: Cost Discipline — Scheduled Crons (Mar 12)

**Key commits:** `cdf1ed1`, `b6144d1`, `e00a62b`

**What landed:**

`non-prod-stop.yaml`:
- Two crons (4 AM and 5 AM UTC) for DST coverage
- Internal `TZ=America/Chicago` time check
- OIDC auth, no static keys
- Preflight check for graceful exit when cluster doesn't exist
- Scales nodegroup to `desiredSize=0`

`non-prod-start.yaml`:
- Two crons (1 PM and 2 PM UTC) for DST coverage
- Same OIDC + preflight pattern
- Scales nodegroup to `desiredSize=2` at 8 AM Chicago

**Math:** Cluster up ~9 hours/day, down ~15 hours/day. **~62% compute savings.**

### Track 3: Cost Governance — Daily Report + AWS Budgets (Mar 12-15)

**Key commits:** `5509125`, `d2c827c`, `fc990f1`

**What landed:**

`cost-report-daily.yaml`:
- Runs 8 AM Chicago daily
- Calls AWS Cost Explorer API (`ce:GetCostAndUsage`)
- Groups by SERVICE and USAGE_TYPE
- Flags risky lines (NAT, ELB, EKS extended support)
- Sends report via SNS → Email
- **Fails workflow if cost > daily limit**

`terraform/cost_guardrails.tf`:
- 1 monthly total budget + 4 per-service budgets
- 3 notification thresholds per budget (50% actual, 80% forecasted, 100% actual)
- KMS-encrypted SNS topic
- AWS Cost Anomaly Detector with daily subscription

### Track 4: Security Hardening (Mar 15)

**Key commits:** `6b6eb99`, `fb4e26b`, `2ea03f6`

**What landed:**

Pod-level + container-level security context on api-gateway:

```yaml
spec:
  template:
    spec:
      securityContext:
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: api-gateway
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: [ALL]
            readOnlyRootFilesystem: true
            runAsGroup: 1000
            runAsNonRoot: true
            runAsUser: 1000
```

### Track 5: Least-Privilege IAM (Mar 15)

**Key commit:** `2ac0e37`

The cost-ops IAM role with 6 statements, each scoped tightly. See [section 4](#cost-guardrails-walkthrough) for full breakdown.

---

<a name="cost-guardrails-walkthrough"></a>
## 4. `cost_guardrails.tf` Complete Walkthrough

### Section 1: Data Sources (Lines 1-2)
```hcl
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
```
Queries AWS for account ID and partition. Makes the code portable across accounts/partitions (aws, aws-cn, aws-us-gov).

### Section 2: Local Variables (Lines 5-31)
Defines:
- `budget_notifications` — the 3-tier alerting schema (50/80/100)
- `service_budgets` — map of 4 AWS services with dollar limits
- `budget_arns` — pre-computed list of all 5 budget ARNs
- `eks_cluster_arn`, `eks_nodegroup_arn_pattern` — for IAM scoping

DRY principle: define notification thresholds ONCE, reuse across 5 budgets.

### Section 3: KMS Key for SNS Encryption (Lines 33-84)
Creates a customer-managed KMS key with:
- Key rotation enabled (annual)
- 7-day deletion window
- Policy granting root admin + SNS service usage (with `aws:SourceAccount` condition to prevent confused deputy attack)

### Section 4: SNS Topic + Email Subscription (Lines 86-95)
Encrypted SNS topic + email subscription. Pub/sub fan-out pattern — easy to add Slack/PagerDuty later.

### Section 5: AWS Budgets (Lines 97-142)
- 1 monthly total budget at $20
- 4 per-service budgets (EKS, EC2-Other, VPC, ELB) via `for_each`
- Each has 3 notification tiers via `dynamic "notification"`
- Each notification publishes to both email AND SNS topic (redundancy)

### Section 6: Cost Anomaly Detection (Lines 144-218)
- External data source to discover existing monitor (avoids "already exists" errors)
- Creates dimensional monitor on SERVICE if none exists
- Daily subscription with $1 minimum threshold
- ML-based pattern detection — AWS-managed model

### Section 7: GitHub OIDC Provider (Lines 220-230)
- URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`
- Thumbprint: GitHub's TLS cert SHA-1
- Trust anchor for OIDC federation

### Section 8: IAM Role for GitHub Actions (Lines 232-344)

**Trust policy** (who can assume): scoped to specific repo + branch via `sub` claim

**Permission policy with 6 statements:**

| # | Statement | Resources | Notes |
|---|---|---|---|
| 1 | CostExplorerRead | `*` | trivy:ignore: AVD-AWS-0057 (API limitation) |
| 2 | BudgetsRead | 5 specific budget ARNs | Scoped tightly |
| 3 | SnsPublish | 1 specific topic ARN | Single topic only |
| 4 | EksScaleNodegroup | Cluster ARN + nodegroup pattern | Narrow actions |
| 5 | RunnerEc2StartStopTagged | `instance/*` + **Condition: ResourceTag/Role** | **ABAC pattern** |
| 6 | RunnerEc2Describe | `*` | API limitation |

### Section 9: CUR + Athena (COMMENTED OUT, Lines 346-419)
Optional enterprise upgrade for SQL-queryable cost data. Commented out to avoid S3/Athena costs on $20/month budget.

---

<a name="foundation-concepts"></a>
## 5. Foundation Concepts (New in Phase 2)

### OIDC Auth (GitHub Actions → AWS)
- **Replaces long-lived AWS access keys** with short-lived federated credentials
- Workflow requests JWT from GitHub → AWS validates against OIDC provider → returns 1-hour STS credentials
- Trust policy `sub` claim restricts by repo + branch
- Required: `permissions: id-token: write`
- Action: `aws-actions/configure-aws-credentials@v4`

### KMS-encrypted SNS
- Customer-managed KMS key encrypts SNS messages at rest
- Cost data is sensitive — SOC2/PCI requirement
- Key rotation enabled, 7-day deletion window
- `aws:SourceAccount` condition prevents confused deputy attack

### AWS Budgets (3-tier)
- **50% ACTUAL** — early warning ("you've spent $10 of $20")
- **80% FORECASTED** — trajectory warning ("you'll hit $20 by month-end")
- **100% ACTUAL** — over budget
- Alerts via SNS + email

### AWS Cost Anomaly Detection
- ML-based pattern detection (AWS-managed model)
- Trained on 90 days of your account's spend history
- DIMENSIONAL or CUSTOM monitor types
- Daily or IMMEDIATE frequency
- $1 minimum threshold filter
- Catches sub-budget anomalies (e.g., forgotten $3/day resource)

### AWS Cost Explorer API
- `ce:GetCostAndUsage` — main API for cost queries
- Doesn't support resource-level permissions (requires `*`)
- Group by SERVICE, USAGE_TYPE, LINKED_ACCOUNT, etc.
- Filter by RECORD_TYPE, dimensions
- Returns JSON; parse with jq

### SNS Fan-out Pattern
- Pub/sub messaging — multiple subscribers per topic
- Today: email; tomorrow could add Slack, PagerDuty, Lambda, SQS
- Email subscriptions require manual confirmation

### Attribute-Based Access Control (ABAC)
- Permissions controlled by **tags**, not just ARNs
- More scalable than maintaining explicit ARN lists
- AWS-recommended modern IAM pattern
- Example: `Condition: ec2:ResourceTag/Role = "github-self-hosted-runner"`

### trivy:ignore with Reasoning
- `# trivy:ignore: AVD-AWS-0057` comment suppresses Trivy rule
- Add reasoning comment for audit trail
- "Justified exception, not silent suppression"
- Auditors want documented exceptions, not blind overrides

### Pod Security Standards (PSS) — Restricted Profile
- Kubernetes' built-in security baseline tiers: Privileged → Baseline → **Restricted**
- Restricted = strictest, recommended for production
- Maps to CIS Kubernetes Benchmark sections 5.1-5.7

### Linux Capabilities
- Kernel-level privileged operations (NOT file permissions)
- Examples: `NET_ADMIN`, `SYS_PTRACE`, `SYS_ADMIN`, `SYS_MODULE`, `CHOWN`, `DAC_OVERRIDE`
- `capabilities.drop: [ALL]` removes them all
- Spring Boot doesn't need any of them

### Seccomp (Secure Computing Mode)
- Linux kernel feature filtering system calls
- `seccompProfile: RuntimeDefault` applies Docker's curated allowlist
- Blocks ~270 dangerous syscalls (ptrace, mount, reboot, keyctl, bpf, etc.)
- Massive attack surface reduction with zero application impact

### readOnlyRootFilesystem
- Mounts container's root filesystem as read-only
- Attackers who escape JVM can't drop binaries, modify configs
- Writable directories must be separate `emptyDir` volumes

### allowPrivilegeEscalation
- Blocks setuid binaries and `sudo` from gaining root
- Defense in depth — even if JVM is compromised, can't escalate

### runAsNonRoot + runAsUser
- `runAsNonRoot: true` makes kubelet refuse to start container as UID 0
- `runAsUser: 1000` forces the specific non-root UID
- Defense in depth even if image accidentally specifies root

### GitHub Actions Cron + DST Problem
- GitHub Actions cron is **UTC-only, no native timezone support**
- DST shifts cause hour drift twice yearly
- Solution: **two crons** for both CST/CDT + internal `TZ=America/Chicago` check
- Workflow attempts twice but executes exactly once per day

---

<a name="hostile-qa"></a>
## 6. 5 Hostile Interview Q&A (Drilled)

### Q1: "How do you keep this project under $20/month? Walk me through your cost discipline."
**R1 Score: 7/10 | R2 Score: 9/10 (LOCKED)**

**Ideal answer (~90 seconds):**

> *"Cost discipline runs across 4 layers — two reactive and two proactive.*
>
> *On the reactive side: spot t3.small instances — roughly 70% cheaper than on-demand. Then two scheduled GitHub Actions crons — `non-prod-stop` scales the nodegroup to zero at 11 PM Chicago, `non-prod-start` scales it back to two at 8 AM. That's another 62% on top of spot. Both use OIDC auth and preflight checks so they exit gracefully if infra is already torn down — no wasted runner minutes.*
>
> *On the monitoring side: `cost-report-daily.yaml` hits AWS Cost Explorer every morning, groups yesterday's spend by service and usage-type, flags risky lines like NAT Gateway and ELB, and fails the workflow if cost exceeds my daily threshold. Cost becomes a CI gate, not a dashboard people forget to check. Reports go via SNS fan-out for email alerting.*
>
> *On the proactive side: AWS Budgets — one monthly total at $20 plus per-service budgets for EKS, EC2-Other, VPC, and ELB. Each has three notification tiers: 50% actual, 80% forecasted, 100% actual — graduated warning before the bill arrives. Alerts go through a KMS-encrypted SNS topic — cost data is sensitive. On top of that, AWS Cost Anomaly Detector — dimensional monitoring on SERVICE, AWS-managed ML model that catches deviations from my historical baseline. Different from Budgets — Budgets is static thresholds, Anomaly Detection is pattern recognition.*
>
> *Together — spot, scheduling, daily report with CI gate, budgets with multi-tier alerts, anomaly detection — keeps my AWS bill under twenty dollars a month while maintaining a production-grade environment."*

**Key secret weapon phrases:**
- *"Two reactive, two proactive"* (4-layer framing)
- *"On top of spot"* (layering insight)
- *"Cost is a CI gate, not a dashboard people forget to check"*
- *"Budgets is static thresholds; Anomaly Detection is pattern recognition"*
- *"Production-grade environment under twenty dollars a month"*

---

### Q2: "What's in your pod security context, and why does each setting matter?"
**R1 Score: 5/10 | R2 Score: 8/10 (LOCKED)**

**Ideal answer (~90 seconds):**

> *"My pods enforce the Pod Security Standards Restricted profile — the strictest tier — with six settings.*
>
> *First, `runAsNonRoot: true` plus `runAsUser: 1000` — Kubernetes refuses to start the container if it tries to run as root. Defense in depth: even if the image accidentally specifies root, the kubelet blocks it.*
>
> *Second, `allowPrivilegeEscalation: false` — blocks setuid binaries and sudo from gaining root. Even if an attacker compromises the JVM, they can't escalate.*
>
> *Third, `capabilities.drop: [ALL]` — drops every Linux capability like NET_ADMIN, SYS_PTRACE, SYS_ADMIN. Spring Boot doesn't need any of them. Attacker can't sniff traffic, trace processes, or load kernel modules.*
>
> *Fourth, `readOnlyRootFilesystem: true` — attackers who escape the JVM can't drop binaries or modify configs. Writable directories are emptyDir volumes mounted separately.*
>
> *Fifth, `seccompProfile: RuntimeDefault` — applies Docker's curated syscall allowlist, blocking around 270 dangerous syscalls like ptrace, mount, reboot, and keyctl. Massive attack surface reduction with zero application impact.*
>
> *Together this maps to CIS Kubernetes Benchmark sections 5.1 through 5.7. If a CVE like runc CVE-2024-21626 ever let an attacker escape the container, these settings would still constrain what they could do. The pod security context is the backup layer when image scanning misses something."*

**Key concept corrections (don't repeat these errors):**
- ❌ Capabilities are NOT read/write/delete file permissions — they are **kernel-level privileged operations**
- ❌ Seccomp is NOT about runtime vs compilation — it's a **syscall filter** blocking ~270 dangerous syscalls
- ❌ runAsUser/Group/fsGroup do NOT set permissions — they set **identity (UID/GID)**

---

### Q3: "Why do you have BOTH AWS Budgets AND a daily cost report? Aren't they redundant?"
**R1 Score: 7.5/10**

**Ideal answer (~75 seconds):**

> *"They're not redundant — they catch different failure modes. I have three layers, not two.*
>
> *AWS Budgets catches threshold violations. I have a monthly $20 total budget plus per-service budgets for EKS, EC2-Other, VPC, and ELB. Each has three notification tiers: 50% actual for early warning, 80% forecasted so I know if my trajectory will hit $20 by month-end, and 100% actual when I've crossed. Alerts go through a KMS-encrypted SNS topic — cost data is sensitive.*
>
> *The daily cost report is my real-time CI gate. `cost-report-daily.yaml` hits Cost Explorer every morning, breaks down yesterday's spend by service and usage-type, flags stealth cost drivers like NAT Gateway hours, ELB utilization, and EKS extended support. It fails the workflow if cost exceeds my daily threshold — cost is a CI gate, not a dashboard people forget to check.*
>
> *And the third layer is AWS Cost Anomaly Detector — ML-based dimensional monitoring on SERVICE. This catches what Budgets misses: a forgotten resource burning $3/day below my $20 budget would never trip a threshold, but it WOULD deviate from my historical baseline. AWS-managed ML model, daily detection, email subscription.*
>
> *Three different mechanisms for three different failure modes: threshold violations, real-time termination, and ML pattern deviations. Together they cover the full cost-monitoring matrix — no single mechanism would catch all three."*

**The 3-Layer Defense Matrix:**
| Layer | Catches | Example |
|---|---|---|
| AWS Budgets | Threshold violations | "Spend hit $16 — 80% forecasted alert" |
| Daily Cost Report | Real-time CI gate | "NAT Gateway spike $5 yesterday — fail workflow" |
| Cost Anomaly Detector | Pattern deviation | "$3/day on AWS Translate I've never used" |

---

### Q4: "Show me your IAM policy for the cost-ops role. Why is it structured this way?"
**R1 Score: 5/10 | R2 Score: 8/10 (LOCKED)**

**Ideal answer (~90 seconds):**

> *"My cost-ops IAM role uses three patterns across six statements: ARN scoping where possible, tag-based conditions where ARNs aren't enough, and documented exceptions where AWS APIs force a `*`.*
>
> *Statement 1 — Cost Explorer's `GetCostAndUsage` uses `Resource: *` because the API doesn't support resource-level permissions. I suppress the Trivy finding with `trivy:ignore: AVD-AWS-0057` plus a reasoning comment — a justified exception, not a silent suppression.*
>
> *Statement 2 — Budgets read is scoped to my five specific budget ARNs from the `service_budgets` local. Other accounts' budgets can't be read. To add a new service budget, I just add to the locals map — scales via `for_each`.*
>
> *Statement 3 — SNS Publish is scoped to my one cost_alerts topic ARN. Cannot publish to any other topic.*
>
> *Statement 4 — EKS scaling is scoped to my specific cluster and nodegroup ARN pattern. Actions are narrow: Describe, List, UpdateNodegroupConfig. Cannot delete cluster, cannot create new nodegroups.*
>
> *Statement 5 — and this is the senior pattern — EC2 Start/Stop. The Resource block is `instance/*` because that's how EC2 ARNs work, but the Condition block requires `ec2:ResourceTag/Role = "github-self-hosted-runner"`. That's Attribute-Based Access Control — permissions controlled by tags, not just ARNs. Even if the role is compromised, the blast radius is one EC2 instance tagged as my runner — not my entire fleet.*
>
> *Statement 6 — EC2 Describe uses `*` because that API also doesn't support tag conditions. AWS limitation, low risk for read-only inventory.*
>
> *The whole policy is enforced in CI by Trivy as a continuous check — if I ever loosen a permission accidentally, the workflow fails."*

---

### Q5: "Your scheduled crons run twice — at 4 AM and 5 AM UTC. Why two crons?"
**Score: 6/10**

**Ideal answer (~30 seconds):**

> *"GitHub Actions cron is UTC-only with no native timezone support. I want my nodegroup to scale down at 11 PM Chicago — but Chicago is UTC-5 in summer and UTC-6 in winter, so a single UTC cron drifts an hour every DST transition. I schedule two crons — 4 AM UTC and 5 AM UTC — to cover both seasons, then add an internal `TZ=America/Chicago` time check that exits early if the actual local hour isn't 11 PM. Net result: workflow attempts twice but executes exactly once at the right local time, all year."*

---

<a name="followup-qa"></a>
## 7. Follow-Up Q&A

### F1: "What happens when AWS reclaims your spot instance mid-deploy?"
> *"Spot interruptions get a 2-minute warning via instance metadata. EKS managed nodegroups handle this gracefully — the node is cordoned (no new pods scheduled), pods are evicted with their terminationGracePeriodSeconds, and a new node is provisioned from the nodegroup's spot pool. For my project, momentary downtime is acceptable. For production with stricter SLAs, I'd run mixed instance types and instance pools to spread reclaim risk."*

### F2: "Your nodegroup is scaled to zero overnight — what about an emergency hotfix at 3 AM?"
> *"`workflow_dispatch` is enabled on `non-prod-start.yaml`, so I can manually trigger nodegroup scale-up from the GitHub Actions UI. Takes about 2-3 minutes. For real production with true 24/7 availability needs, the scale-to-zero pattern wouldn't apply — that's a portfolio cost optimization."*

### F3: "What's a real example of an anomaly the Detector caught that Budgets missed?"
> *"The canonical example: a forgotten resource. Imagine I left an `m5.large` running last week — that's about $3/day. My monthly budget is $20, so the resource would never trip a budget threshold. But $3/day on a service I've never historically used WOULD deviate from my baseline — Cost Anomaly Detection flags it. Budgets handles 'too expensive overall'; Anomaly Detection handles 'unexpectedly different from normal'."*

### F4: "Why $20 and not $50?"
> *"Constraint forces architectural rigor. At $50 I could keep nodes running overnight, use larger instances, skip spot. At $20 I'm forced to use spot, schedule scale-to-zero, gate on cost. The constraint made me build cost discipline as code, not as an afterthought. Real production isn't $20, but the discipline transfers."*

### F5: "What if a syscall your app needs is blocked by RuntimeDefault?"
> *"I'd write a custom seccomp profile, store it on the node, and reference it in the pod spec via `securityContext.seccompProfile.localhostProfile`. Or I could use an Unconfined profile temporarily during debugging. For Spring Boot specifically, RuntimeDefault has never blocked anything I need."*

### F6: "How does `readOnlyRootFilesystem` work with Spring Boot's tmp directory?"
> *"Spring Boot writes to `/tmp` by default for things like JAR extraction and log buffers. With `readOnlyRootFilesystem: true`, I mount an `emptyDir` volume at `/tmp` — it's writable, ephemeral, and isolated from the root filesystem. Same pattern for any directory that needs to be writable."*

### F7: "Why drop ALL capabilities — couldn't your app need NET_BIND_SERVICE for port 80?"
> *"Spring Boot binds to port 8080, not 80. I use a Kubernetes Service to map external port 80 to container port 8080. That way the container never needs `NET_BIND_SERVICE` capability. The Service is the boundary; the container stays unprivileged."*

### F8: "How would you grant break-glass access for emergencies?"
> *"A separate IAM role with stricter trust policy — requires MFA via `aws:MultiFactorAuthPresent` condition, scoped to specific admin users, with CloudTrail auditing every assumption. For automated workflows, I'd never use this role; only humans during true emergencies."*

### F9: "Can your cost-ops role assume other roles?"
> *"No — there's no `sts:AssumeRole` action in the policy. The cost-ops role is a leaf role; it can't pivot. That's deliberate — leaf roles can't chain into broader access."*

### F10: "How would you extend this to multiple AWS accounts?"
> *"Each account gets its own copy of the OIDC provider + IAM role (Terraform handles this via `count` or workspaces). The GitHub workflow specifies which account's role to assume via the `role-to-assume` parameter. For shared cost data, AWS Cost Explorer supports multi-account view via Organizations."*

---

<a name="power-phrases"></a>
## 8. Power Phrases & Secret Weapons

### Cost Discipline
- ✨ **"Four layers — two reactive, two proactive"** — opening framing
- ✨ **"On top of spot"** — layering insight (62% additional savings)
- ✨ **"Cost is a CI gate, not a dashboard people forget to check"** — killer line
- ✨ **"FinOps as code"**
- ✨ **"Production-grade environment under twenty dollars a month"** — closing land
- ✨ **"Budgets is static thresholds; Anomaly Detection is pattern recognition"**
- ✨ **"Three failure modes, three mechanisms — not redundant, complementary"**

### Security
- ✨ **"Pod Security Standards Restricted profile"** (PSS Restricted)
- ✨ **"CIS Kubernetes Benchmark sections 5.1-5.7"**
- ✨ **"Around 270 dangerous syscalls blocked"** (seccomp)
- ✨ **"Linux capabilities like NET_ADMIN, SYS_PTRACE, SYS_ADMIN"**
- ✨ **"Pod security context is the backup when image scanning misses something"**
- ✨ **"Defense in depth — different attack surfaces"**

### IAM
- ✨ **"Three patterns: ARN scoping, tag-based conditions, documented exceptions"**
- ✨ **"Attribute-Based Access Control via tag conditions"**
- ✨ **"Blast radius is one EC2 instance, not my fleet"** — ABAC payoff
- ✨ **"Justified exception, not silent suppression"** — trivy:ignore framing
- ✨ **"Trivy enforces this in CI as a continuous check"** — closing line

### OIDC
- ✨ **"Federated credentials, not stored secrets"**
- ✨ **"Trust policy scopes by repo + branch via JWT sub claim"**
- ✨ **"One-hour credentials, not long-lived keys"**

### Cron / DST
- ✨ **"GitHub Actions cron is UTC-only with no native timezone support"**
- ✨ **"DST drifts an hour every transition"**
- ✨ **"Attempts twice but executes exactly once"**

---

<a name="common-mistakes"></a>
## 9. Common Mistakes to Avoid

| Mistake | Why it hurts |
|---|---|
| Saying "capabilities are read/write/delete" | They're **kernel ops** (NET_ADMIN, SYS_PTRACE), not file permissions |
| Saying "seccomp is about runtime/compilation environment" | It's a **syscall filter** — completely different concept |
| Saying "runAsUser sets permissions" | It sets **identity (UID/GID)**, not permissions |
| Forgetting **AWS Budgets** in cost answer | Half the cost governance story |
| Forgetting **Cost Anomaly Detection** in cost answer | The proactive ML layer |
| Forgetting **spot instances** in cost answer | Layer 1 of the 4-layer model |
| Missing the **$20/month anchor** | The only real number — must land it |
| Saying "EC2" instead of "EC2-Other" | The actual AWS Cost Explorer service name |
| Not naming **PSS Restricted** in security answer | The framework name signals senior |
| Not naming **CIS Kubernetes Benchmark** | Audit framework reference signals senior |
| Not naming **ABAC** when explaining EC2 Condition | Industry term for the pattern |
| Treating Budgets + Daily Report as "redundant" | They catch different failure modes |
| Saying trivy:ignore without reasoning | "Justified exception, not silent suppression" |

---

<a name="cheat-card"></a>
## 10. Cheat Card (One-Page Summary)

### Phase 2 Architecture
```
┌────────────────────────────────────────────────────────┐
│  COST LAYERS                                           │
│  ┌──────────────────────────────────────────────┐     │
│  │ Layer 1: Spot t3.small (~70% off)            │     │
│  │ Layer 2: Cron scale-to-zero (~62% on top)    │     │
│  │ Layer 3: Daily cost report (CI gate)         │     │
│  │ Layer 4: Budgets + Anomaly Detection         │     │
│  └──────────────────────────────────────────────┘     │
│              ↓ alerts via                              │
│  ┌──────────────────────────────────────────────┐     │
│  │ KMS-encrypted SNS topic                      │     │
│  │ → email subscription                         │     │
│  └──────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────┘
                          ↓ managed by
┌────────────────────────────────────────────────────────┐
│  GitHub Actions cost-ops IAM role (OIDC)              │
│  6 statements: ARN-scoped + ABAC + documented excs    │
└────────────────────────────────────────────────────────┘
                          ↓ targets
┌────────────────────────────────────────────────────────┐
│  AWS resources                                         │
│  EKS cluster + nodegroup + budgets + SNS + EC2 runner │
└────────────────────────────────────────────────────────┘
```

### Pod Security Context (6 settings)
```yaml
spec:
  securityContext:
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault         # ~270 syscalls blocked
  containers:
    - securityContext:
        runAsNonRoot: true          # Won't start as UID 0
        runAsUser: 1000             # Force non-root UID
        runAsGroup: 1000
        allowPrivilegeEscalation: false  # No sudo/setuid
        capabilities:
          drop: [ALL]               # No NET_ADMIN, SYS_PTRACE, etc.
        readOnlyRootFilesystem: true  # No drop binaries
```

### IAM Statement Patterns
| Pattern | Use when | Example |
|---|---|---|
| ARN scoping | AWS supports resource-level | `Resources: [arn:aws:eks:...:cluster/demo-eks-cluster]` |
| ABAC (tag conditions) | ARN too broad | `Condition: ec2:ResourceTag/Role = "runner"` |
| Documented exception | AWS API forces `*` | `# trivy:ignore: AVD-AWS-0057` + reasoning |

### Numbers to Remember
- **Spot savings:** ~70% vs on-demand
- **Scheduled scaling savings:** ~62% on top of spot
- **Monthly budget:** $20
- **Budget notification tiers:** 50% actual, 80% forecasted, 100% actual
- **Seccomp blocks:** ~270 dangerous syscalls
- **Anomaly Detector threshold:** $1 minimum impact
- **OIDC credential lifetime:** 1 hour default
- **KMS deletion window:** 7 days

### Interview Q Score Targets
| Question Type | Target |
|---|---|
| Cost discipline walkthrough | 9+ |
| Pod security context | 8+ |
| Budgets vs Daily Report vs Anomaly | 8+ |
| IAM policy walkthrough | 8+ |
| Cron DST handling | 7+ |

### Universal Cost Answer Framework
1. **State the 4 layers** (spot / scheduling / report / budgets+anomaly)
2. **Quantify each layer** (70%, 62%, $1 threshold, 50/80/100)
3. **Land the $20/month anchor**
4. **Drop the killer phrase** ("cost is a CI gate")
5. **Close with operational maturity** ("production-grade")

---

## Phase 2 — COMPLETE ✅

**Average score across 5 questions: 7.7/10 — interview-viable at $120-165K band.**

Next: [Phase 3 — Private EKS + Self-Hosted Runner](phase-3-reference.md) (when ready)
