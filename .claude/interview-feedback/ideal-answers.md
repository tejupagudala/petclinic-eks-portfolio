# Ideal Interview Answers — Reference

Comprehensive ideal answers from interview rounds and study sessions. Organized by topic. Use for deep review and pre-interview cramming.

For 2-sentence summaries, see [study-qa-review.md](study-qa-review.md).
For STAR behavioral stories, see [star-stories/](star-stories/).

**📁 Phase-specific Q&As are now in separate files** (for easier review):
- [phase-1-qa.md](phase-1-qa.md) — CI/CD Foundation (5 Q&As, avg 7.7/10)
- [phase-2-qa.md](phase-2-qa.md) — Cost Discipline & Quality Gates (5 Q&As, avg 7.7/10)
- [phase-3-qa.md](phase-3-qa.md) — Private EKS + Self-Hosted Runner (in progress)
- (more phase files will appear as we drill them)

This file contains only **cross-cutting topics** — narrative opener, behavioral/STAR, K8s debugging, VPC & networking, AWS core services.

---

## Table of Contents

- [Project Narrative (90-second opener)](#project-narrative-90-second-opener)
- [Behavioral / STAR](#behavioral--star)
- [Kubernetes Debugging](#kubernetes-debugging)
- [VPC & Networking](#vpc--networking)
- [AWS Core Services](#aws-core-services)

---

## Project Narrative (90-second opener)

### Q: "Walk me through your project."

### 🔒 LOCKED FINAL VERSION — 2026-05-15 — Score: 9/10

Sai's locked-in narrative. Memorize this verbatim. ~80 seconds spoken. Senior-coded WHY-first opener + tight technical hooks + "happy to dive deep" close.

> *"I come from a software development background, so I wanted to understand completely how end-to-end devops pipelines are implemented and deployed into the cloud platforms. I mean writing the development code is one thing — I want to own what happens after: how it is built, tested, secured, and shipped to production.*
>
> *My goal was to streamline this process, so I implemented an end-to-end devops platform on AWS. It's the Spring Petclinic application — six Spring Boot microservices behind an AWS ALB — running on AWS EKS 1.33, with all infrastructure provisioned by Terraform. On top, full CI/CD pipeline to make deployments faster, safer, and more autonomous, an observability stack, progressive delivery with canary deployments, cost optimizations with cron jobs to scale the nodegroup down at night, and an AIOps assistant layering on top of it.*
>
> *Since my EKS cluster API endpoint is private-only, I built a self-hosted GitHub runner on EC2 within the VPC with its SG locked to my IP.*
>
> *What I'm really proud of is the one-click infra bootstrap — with one click the whole infrastructure is built, and one click tears it down. Happy to dive deep into any topic you want to explore."*

**Why this version wins (the senior signals):**
- **WHY-first opener** — "I come from a development background... I want to own what happens after" → product-thinking, intent over inventory
- **"Streamline this process"** — clear goal framing
- **"Progressive delivery"** — senior vocab for canary
- **"Deployments faster, safer, more autonomous"** — outcome-focused language
- **Architecture in one breath** — 6 microservices + ALB + EKS + Terraform
- **Security beat** — private endpoint + self-hosted runner + IP-locked SG
- **Pride close + handoff** — "happy to dive deep" hands control back to interviewer

**Hooks INTENTIONALLY reserved for follow-ups (don't volunteer):**
- ❌ RDS MySQL + AWS Secrets Manager → wait for *"tell me about your database"*
- ❌ $20/month → wait for *"how do you control cost?"*
- ❌ Bedrock + 3 evidence sources (CloudWatch Logs / Prometheus / K8s API) → wait for *"tell me about the AIOps"*
- ❌ "Evidence-based rather than hallucinating" → AIOps follow-up
- ❌ Argo Rollouts AnalysisTemplate + 20% traffic + Prometheus query → canary follow-up
- ❌ JaCoCo + SonarCloud + Trivy 3-mode + scan-before-push → CI/CD follow-up

**Iteration journey (for learning value):**
- Round 1 (6/10) — full hook coverage but factually loose (SonarQube vs SonarCloud, dropped Secrets Manager)
- Round 2 (5/10) — fixed factual gaps, stopped at 40% (didn't finish narrative)
- Round 3 (7/10) — completed all beats, but scrambled order (CI/CD before ARCH) and "Travis" instead of "Trivy"
- Round 4 (7/10) — beat-by-beat drilling, plateaued at CI/CD close (kept stopping before Argo CD payoff)
- Round 5 (8/10) — broke through with WHY-first authentic voice, dropped 6 hooks
- **🔒 Locked (9/10)** — preserved WHY-first voice + restored 3 critical hooks (Terraform, 6 services, ALB)

---

### Historical Round 1 — 2026-05-15 — Score: 6/10

**Sai's answer (paraphrased):** Hit all 6 structural hooks (architecture / CI-CD / canary / cost / AIOps / bootstrap pride). Strong open, strong close. Lost points for: (1) dropped Secrets Manager from RDS line, (2) "for now I will later improvize" confidence killer on AIOps line, (3) SonarQube/SonarCloud precision mix-up, (4) several awkward verbal phrasings ("and further the docker pushes...", "attched to my IP"), (5) compressed Trivy detail (didn't distinguish FS scan from image scan).

**What to fix to reach 8/10:**
- Restore Secrets Manager hook on RDS line
- Reframe AIOps "future work" as natural next iteration, not as "not done yet"
- Say SonarCloud (SaaS) + JaCoCo as two distinct tools
- Practice tighter phrasings out loud

**Ideal answer (polished target — 80-95 seconds spoken):**

> "I built an end-to-end DevOps platform on AWS — the Spring Petclinic microservices application running on EKS, with full CI/CD, Argo Rollouts canary deployments, observability, and an AIOps assistant layered on top.
>
> It's six Spring Boot microservices behind an AWS ALB, running on EKS 1.33 with spot t3.small nodes for cost savings. All infrastructure is provisioned with Terraform — VPC, EKS, and RDS MySQL with credentials sourced from AWS Secrets Manager. The EKS API endpoint is private-only, so I built a self-hosted GitHub Actions runner on EC2 inside the VPC, with a security group locked to my IP.
>
> The CI/CD pipeline does Maven build, JaCoCo for code coverage, SonarCloud for static analysis, and Trivy scans on both filesystem and image before push. Then it pushes the image and automatically bumps the tag on the Kubernetes manifest.
>
> The api-gateway uses Argo Rollouts for canary deployments — 20% traffic first, a Prometheus AnalysisTemplate validates latency and error rate, then a manual approval gate releases the remaining traffic.
>
> For cost discipline, I run nightly cron workflows that scale the nodegroup to zero and bring it back at noon — keeps my AWS bill under twenty dollars a month.
>
> The newest piece is an AIOps assistant — a Spring Boot service backed by AWS Bedrock that pulls evidence from CloudWatch Logs, Prometheus metrics, and the Kubernetes API, then returns an evidence-based root-cause analysis with confidence and recommended fix. It currently delivers service-level diagnosis, with platform-wide as the natural next iteration.
>
> What I'm proudest of is the infra-bootstrap workflow — one click brings the whole platform up from zero, and one click tears it all down."

**Likely follow-ups (be ready for any of these):**
- *"Why spot t3.small — what happens when AWS reclaims a node?"*
- *"Why self-hosted runner instead of GitHub-hosted? What does the runner cost you?"*
- *"Walk me through the canary AnalysisTemplate — what query does it run?"*
- *"How do you rotate the Secrets Manager credentials, and how does the app pick up the new password?"*
- *"What's in the Bedrock prompt? How do you avoid prompt injection from log lines?"*
- *"Your bootstrap is one click — what happens if it half-succeeds? How do you recover?"*
- *"What did you cut to keep this under $20/month?"*

**Hook-coverage rubric used:**
1. Architecture (services + ALB + EKS + Terraform) — required
2. CI/CD pipeline detail (Maven → quality gates → image push → tag bump) — required
3. Canary mechanic (Rollouts + 20% + Prometheus + manual approval) — required
4. Cost discipline (cron + $20/mo) — required
5. AIOps (Bedrock + 3 evidence sources + structured response) — required
6. Operational pride close (bootstrap one-click) — required

---

## Phase 2 — MIGRATED

Phase 2 Q&As have been moved to **[phase-2-qa.md](phase-2-qa.md)** for easier review.

The migrated content below is preserved temporarily for safety — feel free to delete this section once you've confirmed the migration looks good.

<details>
<summary>Click to expand original Phase 2 content (now duplicated in phase-2-qa.md)</summary>

### Q1: "How do you keep this project under $20/month? Walk me through your cost discipline."

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

### Q2: "What's in your pod security context, and why does each setting matter?"

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

### Q3: "Why do you have BOTH AWS Budgets AND a daily cost report? Aren't they redundant?"

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

### Q4: "Show me your IAM policy for the cost-ops role. Why is it structured this way?"

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

</details>

---

## Behavioral / STAR

### Q: "Tell me about a time you improved a CI/CD pipeline."

> **(Situation)** In my Spring Boot microservices project on EKS, I had CI checks for SonarCloud and Trivy running on every PR, but those are static checks — they can't catch runtime regressions like increased 5xx error rates or latency spikes that only appear under real traffic. A bad image could still reach production and impact 100% of users instantly.
>
> **(Task)** I needed a deployment strategy that would catch runtime issues *before* full rollout, with automated rollback — not just manual intervention.
>
> **(Action)** I introduced Argo Rollouts for the api-gateway service, since it's the user-facing entry point. I configured a canary strategy with three traffic weights — 20%, 50%, 100% — backed by three Kubernetes services: root, stable, and canary, with the AWS ALB splitting traffic between stable and canary pods. I then wrote an AnalysisTemplate that queries Prometheus every 30 seconds for the 5xx error rate over a 5-minute window. If error rate exceeds 5%, Argo automatically aborts the rollout and ALB shifts 100% of traffic back to the stable version. Between the 50% and 100% steps, I added a manual approval pause. I chose canary over blue-green because blue-green doubles infrastructure cost — canary gives progressive exposure on the same node footprint.
>
> **(Result)** Deployments now surface regressions at the 20% stage instead of 100%, limiting blast radius by 5x. Rollback time dropped from a manual `kubectl rollout undo` (minutes) to automated abort (under 1 minute). And because the analysis is Prometheus-driven, the gate is objective — no "LGTM" guesswork.

**Likely follow-ups:**
- Why 5% as error threshold? → Based on baseline error rate; 2-3x baseline signals regression
- What if Prometheus is down? → AnalysisTemplate treats query failures as inconclusive; rollout pauses
- Why only api-gateway? → User-facing entry point with measurable ALB metrics; backend services have lower blast radius

---

### Q: "Tell me about a time you debugged a production issue."

> **(Situation)** I was running seven Spring Boot microservices on my EKS cluster with 2 spot t3.small nodes. After deploying all services plus the monitoring stack (Prometheus and Grafana), my customers-service pod kept restarting every few minutes with a CrashLoopBackOff.
>
> **(Task)** I had to find out why it was crashing and fix it so the services stayed up reliably.
>
> **(Action)** I started with `kubectl get pods -n petclinic` and saw the pod was in CrashLoopBackOff with 5 restarts. Logs showed nothing useful — the app would start up, then stop mid-request. So I ran `kubectl describe pod` and saw the key line: `Last State: Terminated, Reason: OOMKilled, Exit Code: 137`. That told me the kernel was killing the container for using too much memory.
>
> Next I had to figure out — was the pod's memory limit too low, or was the node out of memory? I ran `kubectl top nodes` and saw the node was at 95% memory. Then `kubectl top pods` showed Java services were each using around 400 MB, but their memory *limit* was set to 512 MB — very tight. The real issue: Spring Boot's JVM doesn't respect container memory limits by default, so it was trying to grow its heap past the limit.
>
> I fixed it in two steps. First, I added `-XX:MaxRAMPercentage=75` to the JVM so the heap stays inside the container limit. Second, I bumped the pod memory request to 512 MB and limit to 768 MB. For long-term safety, I enabled the Cluster Autoscaler so the node group can scale from 2 to 4 nodes if memory pressure returns.
>
> **(Result)** Pod restarts dropped from multiple per hour to zero. Node memory usage stabilized around 70%. And I wrote a small runbook entry so next time OOMKilled shows up, the first check is `kubectl describe pod` → `Last State`, not `kubectl logs`.

**Key teaching points embedded:**
- `kubectl describe` shows OOMKilled, not `kubectl logs`
- JVM doesn't respect cgroup limits without `-XX:MaxRAMPercentage`
- Two-part fix: immediate (JVM tuning) + long-term (autoscaler)

---

## Kubernetes Debugging

### Q: "What's the major difference between `kubectl describe` and `kubectl logs`?"

> `kubectl describe` shows what **Kubernetes** thinks about the pod — events from the scheduler and kubelet, last termination state, restart count, OOMKilled reasons, ImagePullBackOff errors, scheduling failures. It's the *infrastructure* view.
>
> `kubectl logs` shows what the **application** wrote to stdout/stderr — log lines, stack traces, startup messages. It's the *application* view.
>
> They answer different questions. For OOMKilled, ImagePullBackOff, or Pending pods → use describe (logs show nothing useful). For app-level errors like database connection failures, bad config, or 500s → use logs.
>
> **Rule of thumb: describe first, logs second.** Describe tells you if it's a Kubernetes problem or an app problem. If it's Kubernetes (scheduling, image pull, OOM), describe has your answer. If it's an app problem, then go to logs — and use `--previous` if the pod has already crashed and restarted, or you'll be reading the new container's logs instead of the dead one's.

---

### Q: "How do you check pod memory usage in Kubernetes?"

> I use `kubectl top pods` and `kubectl top nodes`, but those require **metrics-server** to be installed in the cluster — it's not part of vanilla Kubernetes. On EKS specifically, I install it as part of cluster bootstrap. For historical memory trends I'd go to Prometheus/Grafana instead, since metrics-server only holds the latest data point — no history.
>
> Without metrics-server, `kubectl top` returns "Metrics API not available" and HPA (Horizontal Pod Autoscaler) won't work either, since HPA reads CPU/memory from the same Metrics API.

---

## VPC & Networking

### Q: "Walk me through public vs private subnets — what makes a subnet public, and why have both?"

> **(Why have both)** A VPC is an isolated network in AWS. I split traffic into two tiers:
>
> - **Public subnets** — for resources that need direct internet access. In my Petclinic project, this is the AWS ALB sitting in front of the api-gateway, plus the NAT gateway.
> - **Private subnets** — for everything else: EKS worker nodes, RDS database, application pods. These shouldn't be directly reachable from the internet — security best practice. If they need outbound internet (like pulling Docker images from ECR), they go through the NAT gateway.
>
> I deploy these subnets across **3 availability zones** for high availability — if one AZ fails, traffic shifts to the others.
>
> **(What technically makes a subnet public)** It's purely about routing. A subnet is "public" if its associated route table has a route `0.0.0.0/0 → igw-xxx`. That's the only thing that defines it. AWS doesn't have an "isPublic" flag — it's all routing. Private subnets typically have `0.0.0.0/0 → nat-gateway-xxx` instead, which gives outbound-only internet access. For an instance in a public subnet to actually receive traffic, you also need `Auto-assign Public IP` enabled, or the instance won't have a public IP for the IGW to route to.

**Common mistakes to avoid:**
- Saying "subnets are configured public/private with a checkbox" — wrong, it's routing
- Forgetting to mention 3 AZs / HA story
- Saying NAT gateway is for "databases" — it's for outbound *internet*, not internal traffic

---

### Q: "Security Groups vs NACLs — what's the difference, and where do you use each?"

> **(Stateful vs stateless)** Security Groups are stateful — if I allow inbound traffic on a port, the response traffic going back out is automatically allowed. NACLs are stateless — I have to write both inbound and outbound rules explicitly, including for return traffic on ephemeral ports.
>
> **(Where they attach)** Security Groups attach to individual resources — EC2 instance, RDS database, ALB, Lambda. NACLs attach to subnets and apply to every resource in that subnet. Memory hook: SG = wraps a Server. NACL = wraps a Network/subnet.
>
> **(Allow vs deny)** Security Groups only support **allow** rules — there's no way to write "deny X" in an SG. NACLs support **both allow and deny**, which is useful when I need to explicitly block a known bad IP range. Default NACLs allow everything; custom NACLs deny everything until I add rules.
>
> **(In my Petclinic project)** I rely primarily on Security Groups because they're easier to manage and **SG-to-SG references** handle scaling automatically. The pattern:
>
> - **ALB SG** → allows inbound 443 from `0.0.0.0/0`
> - **EKS Worker Node SG** → allows inbound from the ALB's SG on the NodePort range
> - **RDS SG** → allows inbound 3306 from the EKS Worker Node's SG
>
> All this is internal VPC traffic — no NAT gateway involved between pods and RDS, since both live inside the same VPC and the local route handles that. NAT only comes into play for outbound internet, like EKS nodes pulling images from ECR.
>
> I'd add NACLs as a second layer only if I needed to explicitly block traffic — for example, denying a known malicious CIDR range hitting the ALB.

**Critical gotchas (commonly inverted):**
- SG = resource-level, NACL = subnet-level (NOT the reverse)
- SG only has allow; NACL has both allow + deny
- NAT gateway is for OUTBOUND INTERNET ONLY — not for pod→RDS within the same VPC
- Use SG-to-SG references instead of IP whitelists — auto-handles scaling

---

### Q: "What are VPC Endpoints, why use them, and what's the difference between Gateway and Interface endpoints?"

> **(Two problems with the default NAT-based flow)** When pods in private subnets call AWS services like S3 or ECR by default, traffic exits via NAT gateway → public internet → back into AWS. Two issues:
>
> 1. **Cost** — NAT charges $0.045/hour + $0.045/GB processed. Every ECR image pull or S3 read incurs data transfer charges.
> 2. **Security & compliance** — traffic leaves the VPC and traverses the public internet. Even though it's encrypted, it doesn't satisfy frameworks like HIPAA, PCI-DSS, or FedRAMP that require AWS service traffic to stay on the AWS backbone.
>
> **(The solution: VPC Endpoints)** Provide private connectivity from the VPC to AWS services without traversing the internet. Two flavors:
>
> | | Gateway Endpoint | Interface Endpoint |
> |---|---|---|
> | **Powered by** | Route table entry | AWS PrivateLink (ENIs) |
> | **Supported services** | **Only S3 and DynamoDB** | 100+ services (ECR, Secrets Manager, STS, KMS, SSM, etc.) |
> | **Cost** | **FREE** | ~$0.01/hour per endpoint per AZ + $0.01/GB |
> | **Mechanism** | Adds route to S3 prefix list, traffic stays in VPC | Creates ENI with private IP + AWS-managed DNS hostname |
>
> **(In my Petclinic project)** S3 always gets a gateway endpoint — it's free, no excuse not to. For interface endpoints I'd prioritize:
> - **ECR** — needs TWO endpoints: `ecr.api` (auth) AND `ecr.dkr` (image data). Plus the S3 gateway endpoint, because ECR stores image layers in S3.
> - **Secrets Manager** — for DB credentials
> - **STS** — for IRSA token exchanges (every pod doing AWS API calls hits STS)
>
> Since interface endpoints scale per-AZ (~$7.20/month each), on a $20/month budget I'd carefully measure NAT data transfer cost vs endpoint hourly cost before adding all of them.

**Critical gotchas (commonly missed):**
- **S3 gateway endpoint is FREE** — always add it
- **ECR needs TWO interface endpoints + the S3 gateway endpoint** — image layers live in S3
- **Interface endpoints scale per-AZ** — multiply hourly cost by AZ count
- **PrivateLink is the underlying tech** for interface endpoints
- **Endpoints have their own security groups** — don't forget to allow traffic from your pods' SG

---

### Q: "You're using a single NAT gateway across 3 AZs. What's the failure mode and the production-grade alternative?"

> **(Failure scenario)** With one NAT gateway, all three private subnets share the same private route table pointing at that NAT. If the NAT's AZ goes down, **all three private subnets lose outbound internet** — pods across every AZ can't pull images from Docker Hub, can't reach external APIs, can't refresh IRSA tokens through the public STS path. Blast radius is the entire VPC, even though only one AZ failed.
>
> **(Production alternative)** Deploy **one NAT gateway per AZ**, with **one private route table per AZ**, each pointing at its local NAT. Now an AZ failure only impacts that AZ's pods — the other two stay online. Cost goes from one NAT (~$32/month) to three (~$96/month), but you also avoid the cross-AZ data transfer charges that single-NAT setups incur ($0.01/GB) when pods in AZ-B and AZ-C send traffic through a NAT in AZ-A.
>
> **(Trade-off)** Single-NAT is fine for portfolios and non-prod where there's no SLA and one-hour outages are acceptable. For production, I'd ask: What's the SLA (99.9 vs 99.99)? What's the cost of one hour of outbound failure? What's the data egress volume — because at high volume, cross-AZ charges in single-NAT can exceed the cost of three NATs anyway.
>
> **(Cheaper alternative to NAT gateway)** A **NAT Instance** — a self-managed EC2 instance running NAT software (e.g., the open-source `fck-nat` AMI) — costs ~$3/month on a `t4g.nano` vs ~$32/month for NAT gateway. Trade-off: you manage patches, HA, and bandwidth limits yourself. **VPC endpoints help reduce NAT traffic for AWS services** (S3, ECR, Secrets Manager, STS) — but they don't replace NAT for non-AWS internet like Docker Hub, GitHub, or external APIs.

**Critical gotchas:**
- One-NAT-per-AZ requires **one route table per AZ** — not just three NATs sharing one route table
- VPC endpoints are NOT a full NAT replacement — they only cover AWS services
- Single-NAT setups have hidden cross-AZ data transfer charges ($0.01/GB)
- NAT Instance is the cost-optimization answer interviewers want — `fck-nat` is the famous open-source AMI

---

### Q: "Trace the full network path from a user's browser to a pod and back, including DB query."

> **(DNS Resolution)** Browser checks cache → OS resolver → public DNS. The OS queries an authoritative chain: `.com` TLD → my domain's nameservers (Route 53). Route 53 has a hosted zone for `petclinic.example.com` with an **Alias record** (not CNAME — Alias is AWS-specific and free) pointing to my ALB's DNS name. Route 53 returns one of the ALB's public IPs.
>
> **(Hitting AWS)** Browser opens TCP 443 to that IP. Packet travels the internet, enters AWS via the **Internet Gateway** attached to my VPC, gets routed to the **public subnet** where the ALB has its ENI. **TLS terminates at the ALB** — it has the cert via ACM and decrypts the request.
>
> **(ALB Routing)** ALB has a Listener on 443 with **rules** like `path: /owners/* → target group X`. EKS uses **IP target mode** by default (set up by the AWS Load Balancer Controller running inside the cluster) — meaning targets are pod IPs directly, not node IPs. Possible because the **AWS VPC CNI** plugin gives every pod a real VPC IP.
>
> **(ALB → Pod, no NAT involved)** ALB sends the request to pod IP, e.g., `10.0.2.Y:8080`. This is VPC-internal traffic, handled by the VPC's automatic local route (`10.0.0.0/16 → local`). The pod's SG must allow inbound 8080 from the ALB's SG via SG-to-SG reference. AWS VPC CNI routes the packet from node ENI to pod's network namespace.
>
> **(Inside the Cluster)** api-gateway pod calls `customers-service.petclinic.svc.cluster.local:8080`. **CoreDNS** resolves this to the ClusterIP. ClusterIP is virtual — **kube-proxy** maintains iptables (or IPVS) rules that DNAT it to a real backend pod IP. Traffic rewrites and routes via VPC local to the destination pod.
>
> **(Pod → RDS, no NAT involved)** customers-service queries `petclinic-db.xxx.rds.amazonaws.com:3306`. The RDS endpoint resolves to a private IP in the VPC. Routed via VPC local — never leaves the VPC. RDS SG allows inbound 3306 from customers-service pod's SG.

**The NAT Gateway Rule (memorize this):**
> NAT gateway is ONLY in the path for **outbound traffic from private subnets going to the public internet**. It is NEVER in the path for:
> - Inbound traffic (ALB → pod)
> - Pod-to-pod within the cluster
> - Pod-to-RDS within the same VPC
> - Pod → AWS service via VPC endpoint

**Critical concepts to mention:**
- **Route 53 Alias record** (not CNAME) for AWS resources — free and faster
- **TLS terminates at ALB** — backend can be HTTP or re-encrypted
- **ALB IP target mode** + **AWS VPC CNI** = pods get real VPC IPs, ALB targets pod IPs directly
- **AWS Load Balancer Controller** is what creates ALBs from K8s Ingress resources
- **kube-proxy iptables** translates ClusterIP → pod IP on every node
- **CoreDNS** handles `*.svc.cluster.local` resolution
- **VPC local route** (`10.0.0.0/16 → local`) handles ALL intra-VPC traffic — no NAT needed

---

### Q: "How do you connect multiple VPCs and on-premises networks in AWS? When would you pick VPC Peering vs Transit Gateway?"

> **(Two options)** AWS gives you two main patterns: **VPC Peering** (point-to-point) and **Transit Gateway / TGW** (hub-and-spoke). Peering is a direct 1:1 connection and is **non-transitive** — A↔B and B↔C don't give you A↔C. TGW is a regional managed service that acts as a routing hub: every VPC attaches once to the TGW, and TGW handles forwarding.
>
> **(Scaling math)** Peering is **O(N²)** — to fully mesh 12 VPCs, you need 12×11/2 = 66 peerings, each requiring route tables on both sides. A 13th VPC adds 12 more peerings. TGW is **O(N)** — 12 attachments, one per VPC; a 13th VPC is just one more attachment. **Past ~5 VPCs, TGW wins on operational simplicity.**
>
> **(Enforcement: who can reach who)** The mechanism is **Transit Gateway Route Tables** (different from VPC route tables). Each TGW attachment is associated with a TGW route table. To enforce "Petclinic can reach VPC-B and VPC-C but NOT VPC-D," Petclinic's TGW route table has routes only to VPC-B and VPC-C attachments — no route for VPC-D. Without a route, traffic literally has nowhere to go. **Routing IS the security boundary** — layer security groups and NACLs on top for defense in depth.
>
> **(On-prem connectivity — 3 options)**
>
> 1. **Site-to-Site VPN** — encrypted IPsec over the public internet. Cheap (~$0.05/hour/tunnel), ~1.25 Gbps per tunnel, sets up in minutes. Use for dev/test or as backup.
> 2. **AWS Direct Connect (DX)** — dedicated fiber link to AWS, 1–100 Gbps, low latency. Takes weeks-months to provision. Use for production, large data transfer, latency-sensitive workloads.
> 3. **Hybrid (modern pattern)** — attach both VPN and Direct Connect Gateway to the **same Transit Gateway**. TGW becomes the hub for VPCs AND on-prem.

**Critical gotchas:**
- "Transit VPC" (with EC2 routers) is the **deprecated legacy** pattern from 2017 — never say this in 2026 interviews. Always say **Transit Gateway / TGW**.
- VPC peering is **non-transitive** — this is the most common conceptual gotcha
- TGW Route Tables (not VPC route tables) are the access control mechanism
- **AWS Outposts is NOT a connectivity option** — it's AWS hardware running in your data center for hybrid compute
- VPC peering is FREE (just data transfer); TGW costs $0.05/hour per attachment + data
- For multi-account TGW sharing, use **AWS RAM** (Resource Access Manager)

---

## AWS Core Services

### Q: "What's the difference between a Security Group and a Network ACL?"

> Security Groups and NACLs are both AWS firewall layers, but they operate at different scopes and behave differently.
>
> **1. Level / Scope:**
> - **Security Group** attaches to an **ENI (instance level)** — protects individual EC2/RDS/Lambda ENIs.
> - **NACL** attaches to a **subnet** — protects everything in that subnet.
>
> **2. State:**
> - **SG is stateful** — if you allow inbound on port 443, return traffic is automatically allowed. You only configure one direction.
> - **NACL is stateless** — return traffic is NOT remembered. You must explicitly allow both the inbound rule AND the outbound rule on **ephemeral ports (1024–65535)**.
>
> **3. Rule types:**
> - **SG = allow-only**. There is no "deny" rule — anything not explicitly allowed is implicitly denied.
> - **NACL = allow + deny**, evaluated in **numbered order, lowest first, first match wins**. This is what makes NACLs useful for blocking specific bad IPs or geographic ranges.
>
> **How they work together:** Traffic entering a VPC must pass **both** layers. NACL acts as the first line of defense at the subnet perimeter; SG is the last line at the instance. A common pattern: NACLs deny known-bad IP ranges broadly; SGs handle app-specific allow rules (e.g., "only ALB SG can reach app SG on port 8080").

**Likely follow-ups:**
- *"Why are ephemeral ports needed in NACL?"* — Because TCP return traffic uses a random high port (1024–65535) chosen by the client/OS. Since NACL is stateless, it doesn't know the connection's origin, so you must blanket-allow the ephemeral range outbound.
- *"Can you reference another SG inside an SG rule?"* — Yes. e.g., `Source: sg-app` allows traffic from any ENI attached to that SG. NACLs only accept CIDRs — no SG references, no DNS names.
- *"What's the default behavior?"* — Default SG: allow all outbound, deny all inbound. Default NACL (on default VPC): allow all in/out. Custom NACL: deny all in/out by default.
- *"Limits?"* — Default 60 inbound + 60 outbound rules per SG (can request increase to 1000). NACL: 20 rules per direction (hard cap 40).

---

### Q: "IAM User vs IAM Role — when do you use one over the other?"

> Both are **IAM identities** with attached permission policies, but the core difference is in the **credentials model**.
>
> **IAM User** is a **long-term identity with permanent credentials.** It has either a console password, programmatic access keys (access key ID + secret access key), or both. These credentials don't expire until you rotate or delete them. Designed for **humans** (engineers logging into the console) or, historically, for applications outside AWS that needed to call AWS APIs.
>
> **IAM Role** is a **short-term identity with no permanent credentials.** You don't "log in" as a role — you **assume** it. When assumed, AWS STS hands out **temporary credentials** (access key + secret + session token) that expire in 1 hour by default, max 12 hours. Every role has a **trust policy** declaring *who is allowed to assume it* — an AWS service, another account, a federated identity, or a specific user.
>
> **Three big reasons roles beat users for workloads:**
> 1. **No long-term secrets to leak.** A hardcoded access key in code is the #1 cause of AWS account compromises. Roles auto-rotate.
> 2. **Auditable.** Every `AssumeRole` call lands in CloudTrail with the principal who assumed it — so you can trace which user assumed which role at what time.
> 3. **Least privilege made easy.** A user can be granted permission to assume a role only when they need it (e.g., `sts:AssumeRole` to a `BillingReadOnly` role), instead of permanently holding billing access.
>
> **In my Petclinic project**, I use **IRSA** — IAM Roles for Service Accounts. Instead of giving the EKS worker node a broad IAM role and letting every pod use it, I create a dedicated IAM role per workload (e.g., `aws-load-balancer-controller-role`), then bind it to a Kubernetes ServiceAccount via OIDC. The pod's containers get temporary STS credentials specific to that workload — never any long-term keys.
>
> **Rule of thumb:** in modern AWS, **users should be the exception, not the default.** Humans should log in via **AWS SSO / IAM Identity Center** (federated → assumes a role). Workloads should use roles via IRSA, EC2 instance profiles, or Lambda execution roles. The only IAM users that should exist are break-glass admin accounts and legacy 3rd-party integrations.

**Mental picture:**

```
IAM User: deepak                      IAM Role: PetclinicS3Writer
  permanent credentials                 trust policy: "EC2 can assume me"
  - console password                    permission policy: s3:PutObject
  - access key + secret key
  attached policies:                    (no credentials of its own)
  - AdministratorAccess

                                        When EC2 needs S3 access:
                                        1. Calls STS:AssumeRole
                                        2. Gets temporary token (1 hour)
                                        3. Uses token for S3
                                        4. Token auto-rotates
```

**Likely follow-ups:**
- *"How does an EC2 instance assume a role?"* → Via the **EC2 instance profile** (a wrapper around an IAM role). EC2 metadata service at `169.254.169.254/latest/meta-data/iam/security-credentials/<role-name>` returns rotating STS tokens that the AWS SDK picks up automatically.
- *"Trust policy vs permission policy?"* → **Trust policy** = WHO can assume the role (the *Principal* — an AWS service, account, or federated identity). **Permission policy** = WHAT the role can do once assumed (the *Actions* on which *Resources*). Both must allow the operation.
- *"How would you give a user in account A access to S3 in account B?"* → Create a role in account B with a trust policy that allows account A as principal. The user in account A calls `sts:AssumeRole` against that role ARN and gets temporary credentials scoped to account B.
- *"What is STS?"* → AWS **Security Token Service**. The service that issues temporary credentials when a role is assumed. The `sts:AssumeRole` API is the workhorse; related APIs include `AssumeRoleWithWebIdentity` (for OIDC like IRSA / GitHub Actions), `AssumeRoleWithSAML` (for enterprise SSO), and `GetSessionToken` (for MFA-protected operations).
- *"How long are STS credentials valid?"* → Default 1 hour, max 12 hours (configurable via `DurationSeconds`). Role chaining caps at 1 hour. SDKs auto-refresh before expiry.
- *"Can a role have multiple trust policies?"* → No — one trust policy per role, but it can list multiple principals/conditions inside it.


When a user hits petclinic.example.com, DNS resolves the domain through Route 53. Route 53 has an Alias record pointing to my ALB. The browser connects to the ALB on port 443. TLS terminates at the ALB using an ACM certificate. The ALB listener checks path rules like /owners/* and forwards the request to the correct target group.

In my setup, I use IP target mode with the AWS Load Balancer Controller, so the ALB sends traffic directly to Pod IPs. This works because the AWS VPC CNI gives Pods real VPC IPs. Security groups allow traffic from the ALB to the Pod port.

Inside the cluster, if api-gateway calls customers-service.petclinic.svc.cluster.local, CoreDNS resolves that name to a ClusterIP. The ClusterIP is a stable virtual Service IP. kube-proxy then forwards that traffic to one real backend Pod.

If the service needs data, it connects to the private RDS MySQL endpoint on port 3306. Since RDS is in the same VPC, the traffic stays private and does not use NAT Gateway. The response returns from RDS to the pod, then back through the ALB to the browser.

---

## Project-Story Drill (rehearsal, point-by-point) — 2026-06-15

### Q1 — The 30-second opener (scored 6.5/10)
**Ideal answer (5 beats):**
- It's a Spring Boot microservices app — but the app is the boring part.
- I built the whole production platform around it, end to end, by myself.
- IaC with Terraform · GitOps with Argo CD · canary with Argo Rollouts · observability with Prometheus/Grafana · on AWS EKS.
- The hard constraint: it all runs for **under $20/month**.
- So it's small, but a real, complete, production-shaped platform — and I own every layer.

**Lesson:** The $20/month budget is the hook that makes them lean in — lead with it.
The cold-run / one-click-bootstrap failures are a "what broke" story, NOT the opener.

### Q2 — Architecture walk-through (scored 8/10)
**Ideal answer — follow one code change from push to prod:**
- Foundation: everything is Terraform (VPC, EKS, RDS, IAM, KMS) — rebuildable from an empty account.
- I push a fix → ci.yaml runs: builds, static analysis (SonarCloud), Trivy scans (terraform + k8s + docker image).
- **Scan-before-push** — the registry is a trust boundary; bad images never get in.
- CI doesn't touch the cluster — it updates the image tag in Git, and Argo CD reconciles it into the cluster (GitOps).
- Canary with Argo Rollouts: new api-gateway runs in parallel, 20% of traffic first, analysis template checks
  **success rate ≥ 95% and 5xx ≤ 1%** → if good, promote to 100%; if bad, auto-rollback.
- Watched the whole time by **Prometheus + Grafana for metrics, CloudWatch for logs**.
- Bonus: pipeline authenticates to AWS with **OIDC** — short-lived tokens, no stored keys.

**Recurring mistake to kill:** Prometheus/Grafana = METRICS, not logs. Logs = CloudWatch.

### Concept — Monitoring vs Observability
- Monitoring = watching KNOWN problems (pre-defined metrics/alerts) → "is it broken?"
- Observability = investigating UNKNOWN problems (metrics + logs + traces) → "why is it broken?"
- 3 pillars: metrics, logs, traces. My project has metrics + logs; **tracing is the honest gap.**
