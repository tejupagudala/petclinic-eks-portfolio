# Phase 2 — Q&A Drilled Bank

**Phase 2 average score across 5 hostile questions: 7.7/10**

Companion to [phase-2-reference.md](phase-2-reference.md). Reference file = concepts + cheat card. This file = hostile Q&As, ideal answers, and follow-ups.

---

## Table of Contents

- [Q1: "How do you keep this project under $20/month? Walk me through your cost discipline"](#q1-how-do-you-keep-this-project-under-20month)
- [Q2: "What's in your pod security context, and why does each setting matter?"](#q2-whats-in-your-pod-security-context-and-why-does-each-setting-matter)
- [Q3: "Why do you have BOTH AWS Budgets AND a daily cost report? Aren't they redundant?"](#q3-why-do-you-have-both-aws-budgets-and-a-daily-cost-report-arent-they-redundant)
- [Q4: "Show me your IAM policy for the cost-ops role. Why is it structured this way?"](#q4-show-me-your-iam-policy-for-the-cost-ops-role-why-is-it-structured-this-way)
- [Q5: "Your scheduled crons run twice — at 4 AM and 5 AM UTC. Why two crons?"](#q5-your-scheduled-crons-run-twice--at-4-am-and-5-am-utc-why-two-crons)

---

## Q1: "How do you keep this project under $20/month? Walk me through your cost discipline"

**Round 1 — 2026-05-19 — Score: 7/10**
**Round 2 — 2026-05-19 — Score: 9/10** 🔒

**What Sai got right in R2 (the senior signals):**
- ✅ Opened with **"4 layers — two reactive, two proactive"** structural framing
- ✅ Spot t3.small + 70% savings claim
- ✅ Both crons named + 62% additional savings + "on top of spot" layering insight
- ✅ OIDC auth + preflight checks (graceful exit when infra torn down)
- ✅ The killer line preserved: *"terminate workflow instead of sending reports to dashboard which might be skipped"*
- ✅ SNS fan-out pattern named
- ✅ Per-service budgets with **"EC2-Other"** (correct AWS service name)
- ✅ KMS-encrypted SNS with justification ("cost reports are confidential")
- ✅ Cost Anomaly Detector: dimensional + ML + use cases
- ✅ **The $20/month anchor landed in the close**
- ✅ "production grade environment" — operational maturity framing

**What to fix to reach 10/10:**
- Use actual filename `cost-report-daily.yaml` (not `aws-cost-report.yaml`)
- Mention the **3-tier budget notifications** explicitly: 50% actual, 80% forecasted, 100% actual
- Clarify: Cost Anomaly Detector **detects deviations from baseline**, doesn't forecast (forecasting is Budgets' job)

**Ideal answer (~90 seconds spoken):**

> *"Cost discipline runs across 4 layers — two reactive and two proactive.*
>
> *On the reactive side: spot t3.small instances — roughly 70% cheaper than on-demand. Then two scheduled GitHub Actions crons — `non-prod-stop` scales the nodegroup to zero at 11 PM Chicago, `non-prod-start` scales it back to two at 8 AM. That's another 62% on top of spot. Both use OIDC auth and preflight checks so they exit gracefully if infra is already torn down — no wasted runner minutes.*
>
> *On the monitoring side: `cost-report-daily.yaml` hits AWS Cost Explorer every morning, groups yesterday's spend by service and usage-type, flags risky lines like NAT Gateway and ELB, and fails the workflow if cost exceeds my daily threshold. Cost becomes a CI gate, not a dashboard people forget to check. Reports go via SNS fan-out for email alerting.*
>
> *On the proactive side: AWS Budgets — one monthly total at $20 plus per-service budgets for EKS, EC2-Other, VPC, and ELB. Each has three notification tiers: 50% actual, 80% forecasted, 100% actual — graduated warning before the bill arrives. Alerts go through a KMS-encrypted SNS topic — cost data is sensitive. On top of that, AWS Cost Anomaly Detector — dimensional monitoring on SERVICE, AWS-managed ML model that catches deviations from my historical baseline. Different from Budgets — Budgets is static thresholds, Anomaly Detection is pattern recognition.*
>
> *Together — spot, scheduling, daily report with CI gate, budgets with multi-tier alerts, anomaly detection — keeps my AWS bill under twenty dollars a month while maintaining a production-grade environment."*

**The 4-Layer Mental Model (memorize this framing):**
| Layer | Component | Effect |
|---|---|---|
| 1. Cheap compute | Spot t3.small | ~70% off on-demand |
| 2. Scheduled scaling | Cron scale-to-zero | ~62% on top of spot |
| 3. Active monitoring | Daily report → fails CI on overrun | Reactive gate |
| 4. Proactive governance | Budgets + Anomaly Detection | Catches sub-threshold patterns |

**Secret weapon phrases:**
- *"Cost is a CI gate, not a dashboard people forget to check"*
- *"On top of spot"* (the layering insight)
- *"Budgets is static thresholds; Anomaly Detection is pattern recognition"*
- *"Production-grade environment under twenty dollars a month"*

**Likely hostile follow-ups:**
- *"What happens when AWS reclaims your spot instance mid-deploy?"* → Spot interruption handling
- *"Your nodegroup is scaled to zero overnight — what about emergency hotfix at 3 AM?"* → workflow_dispatch override
- *"What's a real example of an anomaly the Detector caught that Budgets missed?"* → forgotten resource scenario
- *"Why $20 and not $50?"* → exercise in constraint forces architectural rigor

---

## Q2: "What's in your pod security context, and why does each setting matter?"

**Round 1 — 2026-05-19 — Score: 5/10** (capabilities + seccomp misunderstood)
**Round 2 — 2026-05-19 — Score: 8/10** 🔒

**What Sai got right in R2:**
- ✅ Fixed capabilities — named real Linux capabilities (SYS_PTRACE, ADMIN)
- ✅ Fixed seccomp — named real syscalls (mount, reboot)
- ✅ Defense-in-depth framing with three "even if" statements
- ✅ All 6 settings hit cleanly (runAsNonRoot, user/group/fsGroup, allowPrivilegeEscalation, drop ALL, readOnlyRootFS, seccompProfile)
- ✅ "Backup gate when CVE scanning misses something" — sophisticated layering insight

**What to fix to reach 10/10:**
- Name **"Pod Security Standards Restricted profile"** (PSS Restricted)
- Name **"CIS Kubernetes Benchmark sections 5.1-5.7"**
- Cite a specific CVE: **runc CVE-2024-21626** (container escape, 2024)
- Add "~270 dangerous syscalls" specificity to the seccomp explanation

**Ideal answer (~90 seconds spoken):**

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
- ❌ Capabilities are NOT read/write/delete file permissions — they are **kernel-level privileged operations** (NET_ADMIN, SYS_PTRACE, SYS_MODULE, CHOWN)
- ❌ Seccomp is NOT about runtime vs compilation environment — it is a **syscall filter** that blocks ~270 dangerous syscalls
- ❌ runAsUser/Group/fsGroup do NOT set "read only access" — they set **identity (UID/GID)** that processes run as

**Secret weapon phrases:**
- *"Pod Security Standards Restricted profile"*
- *"CIS Kubernetes Benchmark sections 5.1-5.7"*
- *"Around 270 dangerous syscalls blocked"*
- *"Pod security context is the backup when image scanning misses something"*

**Likely hostile follow-ups:**
- *"Why drop ALL capabilities — couldn't your app need NET_BIND_SERVICE for port 80?"* → bind to 8080, use Service for port mapping
- *"How does readOnlyRootFilesystem work with Spring Boot's tmp directory?"* → emptyDir volume mounted at /tmp
- *"What if a syscall your app needs is blocked by RuntimeDefault?"* → write a custom seccomp profile, mount via securityContext

---

## Q3: "Why do you have BOTH AWS Budgets AND a daily cost report? Aren't they redundant?"

**Round 1 — 2026-05-19 — Score: 7.5/10**

**What Sai got right:**
- ✅ Opened with proactive/reactive framing
- ✅ Hit all 3 budget tiers (50% actual, 80% forecasted, 100% actual)
- ✅ KMS-encrypted SNS named
- ✅ Killer line preserved: *"CI gate not just sending reports to dashboard"*
- ✅ Precise service names (EC2-Other)
- ✅ OIDC + preflight + graceful exit operational detail
- ✅ Closing differentiation between the two tools

**What to fix to reach 9+/10:**
- **Add AWS Cost Anomaly Detector as the THIRD layer** — without it, the answer is incomplete
- State explicitly: *"they're not redundant — they catch different failure modes"*
- Give concrete examples: forgotten $3/day resource (Anomaly), $16 hits 80% forecast (Budgets), NAT Gateway spike (Daily Report)
- Reframe from "proactive vs reactive" to "three failure modes: threshold, real-time, pattern deviation"

**Ideal answer (~75 seconds spoken):**

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

**Secret weapon phrases:**
- *"Three failure modes, three mechanisms — not redundant, complementary"*
- *"Budgets is static thresholds; Daily Report is real-time gating; Anomaly Detection is pattern recognition"*
- *"Forgotten $3/day resource below threshold but anomalous to my baseline"*

**Likely hostile follow-ups:**
- *"Give me a real scenario where each one fires but the other two don't"* → use the matrix examples
- *"What about CloudWatch Billing Alarms — why not just those?"* → Billing Alarms = threshold only, no service breakdown, no fan-out, no CI gate
- *"Doesn't AWS Cost Explorer have its own alerts?"* → It does (anomaly subs are part of Cost Explorer), but they're notification-only — not a CI gate

---

## Q4: "Show me your IAM policy for the cost-ops role. Why is it structured this way?"

**Round 1 — 2026-05-19 — Score: 5/10** (partial — trailed off before EC2 Condition explanation)
**Round 2 — 2026-05-19 — Score: 8/10** 🔒

**What Sai got right in R2:**
- ✅ Opened with the 3-pattern framing: ARN scoping, tag-based conditions, documented exceptions
- ✅ Cost Explorer `*` correctly explained as documented AWS API limitation
- ✅ Budgets ARN scoping + `for_each` scalability mention
- ✅ SNS scoped to one topic ARN
- ✅ EKS scoped to specific cluster + named what the role CANNOT do
- ✅ EC2 Start/Stop Condition pattern correctly explained
- ✅ EC2 Describe `*` with API limitation reasoning
- ✅ Trivy:ignore reasoning

**What to fix to reach 10/10:**
- Name **"Attribute-Based Access Control" (ABAC)** explicitly when explaining the EC2 Condition
- Add the **"blast radius is one EC2 instance, not my fleet"** payoff line
- Frame trivy:ignore as **"justified exception, not silent suppression"**
- Weave trivy:ignore INTO statement 1 (don't save for the end)
- Close with **"Trivy enforces this in CI as a continuous check"**

**Ideal answer (~90 seconds spoken):**

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

**Secret weapon phrases:**
- *"Three patterns: ARN scoping, tag-based conditions, documented exceptions"* (opening)
- *"Attribute-Based Access Control via tag conditions"* (EC2 statement)
- *"Blast radius is one EC2 instance, not my fleet"* (ABAC payoff)
- *"Justified exception, not silent suppression"* (trivy:ignore framing)
- *"Trivy enforces this in CI as a continuous check"* (closing)

**Likely hostile follow-ups:**
- *"What if you need a new service permission tomorrow?"* → Update the policy in Terraform, PR review, deploy
- *"How would you grant break-glass access for emergencies?"* → Separate role with stricter trust policy + manual approval + CloudTrail audit
- *"Can the cost-ops role assume other roles?"* → No — no `sts:AssumeRole` action in this policy
- *"What about MFA?"* → OIDC federation IS the auth — no human in the loop; for human admin roles, I'd add `aws:MultiFactorAuthPresent` condition

---

## Q5: "Your scheduled crons run twice — at 4 AM and 5 AM UTC. Why two crons?"

**Round 1 — 2026-05-19 — Score: 6/10**

**What Sai got right:**
- ✅ Correctly identified the DST timezone issue
- ✅ Concept of two crons for consistency year-round

**What costs the 4 points:**
- ❌ The internal time-check guard not mentioned (without it, BOTH crons fire, scaling twice/day)
- ❌ Specific framing missing: *"GitHub Actions cron is UTC-only with no native timezone support"*
- ❌ Exact UTC numbers not stated (4 AM UTC = 11 PM Chicago summer, 5 AM UTC = 11 PM Chicago winter)

**Ideal answer (~30 seconds spoken):**

> *"GitHub Actions cron is UTC-only with no native timezone support. I want my nodegroup to scale down at 11 PM Chicago — but Chicago is UTC-5 in summer and UTC-6 in winter, so a single UTC cron drifts an hour every DST transition. I schedule two crons — 4 AM UTC and 5 AM UTC — to cover both seasons, then add an internal `TZ=America/Chicago` time check that exits early if the actual local hour isn't 11 PM. Net result: workflow attempts twice but executes exactly once at the right local time, all year."*

**Secret weapon phrases:**
- *"GitHub Actions cron is UTC-only, no native timezone support"*
- *"DST drifts an hour every transition"*
- *"Internal `TZ=America/Chicago` time check exits early"*
- *"Attempts twice but executes exactly once"*

**Importance: Medium-low** — some interviewers throw it as a details probe; ~5% probability ask. Have the 30-sec answer ready as backup, but don't drill for 10/10.

**Likely hostile follow-ups:**
- *"What if you forget the timezone check guard?"* → Workflow runs twice/day; scaling-to-zero runs twice (idempotent, no harm); scaling-up could try to start a running cluster (also idempotent)
- *"What about EventBridge with timezone support?"* → EventBridge cron is also UTC-only; only Step Functions or Lambda + DateTime libraries solve this natively
- *"How do you handle the leap year edge case?"* → Cron syntax doesn't care; date math in bash handles correctly

---

## Phase 2 — Trajectory Summary

| Question | Round 1 | Round 2 |
|---|---|---|
| Q1 — Cost discipline walkthrough | 7/10 | **9/10** 🔒 |
| Q2 — Pod security context | 5/10 | **8/10** 🔒 |
| Q3 — Budgets vs Daily Report vs Anomaly | **7.5/10** | — |
| Q4 — Cost-ops IAM policy | 5/10 | **8/10** 🔒 |
| Q5 — Two crons (DST) | **6/10** | — |

**Phase 2 average: 7.7/10** — interview-viable at $120-165K band.

**Best score:** Q1 R2 (9/10) — 4-layer framing + killer line + $20 anchor all landed.
**Lowest:** Q5 (6/10) — DST cron question; medium-low priority, not worth chasing 10/10.

**Pattern observation:** Sai shows strong recovery (5→8, 5→8) on re-attempts when given specific framing fixes. Conceptual depth is there; structure benefits from explicit framework names.

---

## 📚 Phase 2 — Follow-up Answer Bank

Full ideal answers for every hostile follow-up across Q1-Q5.

---

### Q1 Follow-ups (Cost Discipline)

**Q1.F1: "What happens when AWS reclaims your spot instance mid-deploy?"**
> *"Spot interruption is announced via the Instance Metadata Service 2 minutes before termination. EKS Managed Node Groups handle this automatically — the node is cordoned, pods are evicted gracefully, and the node group launches a replacement. For mid-deploy resilience: PodDisruptionBudgets ensure minimum replicas stay available during eviction, and Argo Rollouts pauses analysis if pod counts drop. Worst case: 2-minute warning + node replacement ~3 min = 5 min disruption. Production fix: mixed-instance node groups (spot + on-demand fallback), or move critical workloads to on-demand."*

**Q1.F2: "Your nodegroup is scaled to zero overnight — what about emergency hotfix at 3 AM?"**
> *"Two recovery paths. One — `workflow_dispatch` on `non-prod-start.yaml`: manually trigger via GitHub UI from my phone, scales the nodegroup back to 2 in ~3 minutes. Two — emergency procedure: someone calls me, I trigger the scale-up workflow, ~5 min total from page to running pods. Honest tradeoff: this is portfolio scope. Production with revenue traffic would NEVER scale to zero — would use Karpenter for cost optimization while keeping minimum capacity for emergency response."*

**Q1.F3: "What's a real example of an anomaly the Detector caught that Budgets missed?"**
> *"Forgotten resource scenario. I spin up an experimental EFS for a test, forget to delete it. EFS costs $0.30/GB/month — at 50GB that's $15/month, BELOW my $20 budget so Budgets doesn't fire. But Anomaly Detection sees the new pattern (EFS = $0 yesterday, $0.50 today, $1 tomorrow) and alerts on the trajectory. Budgets is threshold-based; Anomaly is pattern-based. Each catches what the other misses."*

**Q1.F4: "Why $20 and not $50?"**
> *"Constraint forces architectural rigor. At $50/month I'd reach for managed convenience — RDS Multi-AZ, NAT Gateway, dedicated runners. At $20, every decision is a tradeoff I have to defend: single-AZ RDS, scaled-to-zero overnight, self-hosted runner instead of NAT. The portfolio narrative is stronger when every architectural choice has an explicit cost defense. Production would budget higher; the discipline transfers."*

---

### Q2 Follow-ups (Pod Security Context)

**Q2.F1: "Why drop ALL capabilities — couldn't your app need NET_BIND_SERVICE for port 80?"**
> *"Bind to port 8080 instead — non-privileged port that needs no capabilities. Then a Kubernetes Service object handles the port 80 → 8080 mapping at the cluster network layer. This is the standard Kubernetes pattern: containers run as non-root on high ports, Services do the privileged port mapping. Drop ALL capabilities, add nothing back, sleep well. If I genuinely needed NET_BIND_SERVICE for some legacy app, I'd add it back specifically — but only that one capability, not the default kernel set."*

**Q2.F2: "How does readOnlyRootFilesystem work with Spring Boot's tmp directory?"**
> *"Spring Boot writes to `/tmp` for compilation cache, JIT artifacts, and temporary uploads. With `readOnlyRootFilesystem: true`, the entire container filesystem is read-only — including `/tmp`. Fix: mount an `emptyDir` volume at `/tmp` — the volume itself is writable but lives outside the read-only root. The pod spec adds `volumeMounts: - name: tmp, mountPath: /tmp` and `volumes: - name: tmp, emptyDir: {}`. emptyDir is ephemeral, scoped to the pod lifetime, perfect for tmp data."*

**Q2.F3: "What if a syscall your app needs is blocked by RuntimeDefault?"**
> *"Write a custom seccomp profile. Two options. One — start with RuntimeDefault, identify the blocked syscall via `dmesg` or audit logs, write a profile that allows just that syscall on top of the default. Two — use the `Localhost` seccomp profile type and load a custom JSON profile from `/var/lib/kubelet/seccomp/profiles/`. Production tip: tools like `seccomp-tracer` or `oci-seccomp-bpf-hook` can auto-generate a tight profile by recording syscalls during a test run."*

---

### Q3 Follow-ups (Cost Detection Layers)

**Q3.F1: "Give me a real scenario where each one fires but the other two don't"**
> *"Three scenarios. **Budgets only**: my standard monthly EKS spend slowly climbs from $18 to $20 to $22 — Budgets fires at $20 threshold; no anomaly because the climb is gradual; no CI gate fire because no new infra is being provisioned. **Anomaly only**: I leave a debug EC2 instance running over the weekend at $50 surprise spend — Budgets doesn't trigger ($50 isn't extreme), but Anomaly Detection sees the sudden weekend spike vs baseline. **CI gate only**: I push a Terraform PR that adds an `aws_eks_node_group` with 10 m5.4xlarge nodes — `infracost diff` flags the $3000/month projected increase and the CI fails RED before merge. Different patterns, different layers."*

**Q3.F2: "What about CloudWatch Billing Alarms — why not just those?"**
> *"Billing Alarms are threshold-only — same as Budgets but cruder. No service breakdown (just total bill), no fan-out (just SNS), no CI gate (purely reactive). Budgets adds service-level breakdown and per-service thresholds. Cost Anomaly Detection adds pattern recognition. Infracost adds preventive CI gating. Defense in depth across 3 different signal types is much more robust than a single threshold."*

**Q3.F3: "Doesn't AWS Cost Explorer have its own alerts?"**
> *"Cost Anomaly Detection IS part of Cost Explorer — they share the underlying data model. But the difference is action: Cost Explorer alerts are notification-only, sent to email. They don't gate CI, don't fan out to PagerDuty, don't integrate with budget workflows automatically. My 3-layer design uses Cost Explorer's signal but adds the missing action layer."*

---

### Q4 Follow-ups (Least-Privilege IAM)

**Q4.F1: "What if you need a new service permission tomorrow?"**
> *"Update the policy in Terraform, PR review, deploy. The IAM policy is in `terraform/iam_cost_ops.tf` as a JSON document. I add the new action (e.g., `cloudwatch:GetMetricData`), open a PR for review (security gate via PR template asking for justification), `terraform apply` to deploy. CloudTrail logs the policy change with my user identity. The whole change is auditable in `git log` + CloudTrail. Production would add a Service Control Policy denial as backstop — even if the policy gets too permissive, SCPs prevent specific actions account-wide."*

**Q4.F2: "How would you grant break-glass access for emergencies?"**
> *"Separate IAM role specifically for break-glass — stricter trust policy requiring MFA + a CloudWatch event triggering on assume. Manual approval workflow: a teammate must approve via Slack before assume succeeds (Lambda-mediated). All actions audited via CloudTrail; CloudWatch alarm on any break-glass assume notifies on-call. Time-bound session via STS `DurationSeconds`. Production AWS Organizations: SCPs deny most actions for the base accounts and only allow them on break-glass."*

**Q4.F3: "Can the cost-ops role assume other roles?"**
> *"No — no `sts:AssumeRole` action in the policy. The role is strictly scoped to its own permissions (nodegroup scale operations). Even if an attacker compromises the GitHub runner, they can only do what the role explicitly allows — they can't pivot to other roles. This is the lateral-movement prevention principle. Production: cost-ops role policy explicitly DENIES `sts:AssumeRole` even at the resource level."*

**Q4.F4: "What about MFA?"**
> *"For OIDC federation (CI-to-AWS) there's no human in the loop — MFA doesn't apply. The trust is established via GitHub's OIDC issuer + my repo identity. For HUMAN admin roles, I'd add `Condition: { Bool: { 'aws:MultiFactorAuthPresent': 'true' } }` to the trust policy. STS AssumeRole calls without MFA would be denied. Combined with IAM Identity Center SSO and short session durations (1 hour max), MFA closes the human credential vector."*

---

### Q5 Follow-ups (DST cron + EventBridge)

**Q5.F1: "What if you forget the timezone check guard?"**
> *"Workflow runs twice per day — once at UTC midnight, once at local midnight equivalent. Scaling-to-zero twice is idempotent (already zero stays zero, no harm). Scaling-up twice tries to start an already-running cluster — also idempotent because the EKS nodegroup update returns success when the desired state already matches. So the duplicate runs are harmless. The guard prevents wasted GitHub Actions minutes more than actual functional issues. Production fix: use Step Functions with `DateTime` library for proper timezone handling."*

**Q5.F2: "What about EventBridge with timezone support?"**
> *"EventBridge cron is also UTC-only — same limitation. AWS officially says 'EventBridge uses UTC for cron expressions.' The workarounds: Step Functions with timezone-aware DateTime libraries, Lambda triggered by EventBridge that re-schedules based on local time, or a 3rd-party scheduler like Easycron. For my portfolio I accept the DST drift; production with strict scheduling SLAs would use Step Functions."*

**Q5.F3: "How do you handle the leap year edge case?"**
> *"Cron syntax doesn't care about leap years — `0 4 * * *` fires on Feb 29 of leap years correctly. Date math in bash also handles correctly via the kernel time APIs. Only humans get confused by leap years; the system handles it transparently. My workflow has no date-arithmetic logic that would break on Feb 29 — pure cron + idempotent scale operations."*

---
