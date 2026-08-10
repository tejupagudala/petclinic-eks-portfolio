# Phase 4 — Q&A Drilled Bank

**Phase 4 in progress. Q1 complete; Q2-Q5 pending.**

Companion to (future) `phase-4-reference.md`. This file = hostile Q&As, ideal answers, and follow-ups for the Bootstrap Stabilization Marathon (Mar 22, 2026).

---

## Table of Contents

- [Q1: "Walk me through your infra-bootstrap workflow"](#q1-walk-me-through-your-infra-bootstrap-workflow)
- Q2: "March 22, you had 20+ commits in one day. Tell me what was happening." (pending — STAR story)
- Q3: "What's the chicken-and-egg problem with OIDC + IRSA, and how did you solve it?" (pending)
- Q4: "ALB Webhook cert state kept getting stale. What was happening?" (pending)
- Q5: "Your bootstrap is idempotent. Walk me through what happens on a re-run." (pending)

---

## Q1: "Walk me through your infra-bootstrap workflow"

**Round 1 — 2026-05-21 — Score: 8.5/10**

**What Sai got right:**
- ✅ Opened with the **5-problem framing** (sequencing, concurrency, idempotency, stale state recovery, auth expiration, diagnostics)
- ✅ Chicken-and-egg explained: self-hosted runner can't boot itself
- ✅ Targeted Terraform apply rationale (private VPC, can't create full stack from GitHub-hosted)
- ✅ Cost-cron edge case acknowledged (waking runner if stopped)
- ✅ Concurrency control with exact flag: `cancel-in-progress = false`
- ✅ Toolchain drift mitigation (install tools every run)
- ✅ Secrets Manager → K8s Secret bridge
- ✅ STS expiration math (20+ min workflow vs 1 hr STS = needs refresh)
- ✅ Helm state recovery cascade (pending → rollback → uninstall → fresh install)
- ✅ ALB dry-run validation mentioned
- ✅ The 2 AM diagnostics framing (killer line)
- ✅ Future iteration: Argo CD Helm migration + S3 diagnostic upload

**What to fix to reach 9.5+/10:**
- Cite specific scale: **635 lines, ~22 minutes end-to-end**
- Mention the **e2e-smoke chain trigger** (workflow_run: completed)
- Get the chronology right: RDS wait comes RIGHT AFTER terraform apply (before tooling)
- Say the word **"idempotent"** explicitly (not just "rerun")

**Ideal answer (~2-3 min spoken):**

> *"My infra-bootstrap is my biggest workflow — 635 lines, ~22 minutes end-to-end — a one-click that gets my whole infrastructure up from scratch after terraform destroy. It solves 5 problems simultaneously: sequencing, concurrency, idempotency, stale state recovery, auth expiration, and diagnostics on failure.*
>
> *Two-job architecture: prepare-runner on GitHub-hosted wakes up my self-hosted EC2 runner — chicken-and-egg because the self-hosted runner can't boot itself. Targeted Terraform apply creates JUST the VPC and runner, not full stack, because the private EKS endpoint isn't reachable from GitHub-hosted runners.*
>
> *Bootstrap job runs on the self-hosted runner: full Terraform apply (EKS, RDS, IAM, KMS — ~15 min), `aws rds wait db-instance-available` because Terraform success doesn't mean RDS is ready for connections, install tooling fresh every run to avoid toolchain drift, configure kubeconfig and persist via `$GITHUB_ENV`.*
>
> *Then platform tools via Helm: ALB Controller, Argo CD, kube-prometheus-stack — each with preflight cleanup that detects `pending-install` state, attempts rollback, falls back to uninstall, then fresh install. Idempotent re-runs.*
>
> *Secrets Manager → K8s Secret bridge for RDS creds, then kubectl apply Petclinic services.*
>
> *Before final readiness checks, refresh STS credentials because the bootstrap can run longer than the 1-hour STS lifetime. Then wait for all rollouts, wait for ALB hostname to actually provision, dry-run validate ALB webhook.*
>
> *Concurrency control: `cancel-in-progress: false` — if another bootstrap is running, wait, don't cancel mid-Terraform-apply or you corrupt state.*
>
> *Failure diagnostics: every potential-failure section has an `if: failure()` dump step that captures pods, logs, events, secrets — so when it fails at 2 AM, the entire debugging context is in the workflow logs. No SSH into the runner.*
>
> *And on success, the `e2e-smoke` workflow auto-triggers via the `workflow_run: completed` chain — three curl calls validate the full path from public ALB through Petclinic services to RDS.*
>
> *Next iteration: migrate the imperative Helm installs to Argo CD's Helm support via App-of-Apps — declarative, less recovery code, self-healing. And upload diagnostic dumps to S3 for searchable post-mortem."*

**Secret weapon phrases:**
- *"5 problems: sequencing, concurrency, idempotency, stale state recovery, auth expiration, diagnostics"*
- *"Chicken-and-egg: self-hosted runner can't boot itself"*
- *"Targeted Terraform apply — VPC + runner only first, full stack later from the runner"*
- *"STS expiration math: 20-min workflow > 1-hour STS — refresh credentials before final checks"*
- *"`if: failure()` diagnostic dumps — debug at 2 AM without SSH"*
- *"e2e-smoke chains via `workflow_run: completed`"*

**Likely hostile follow-ups:**
- *"What if RDS provisioning fails?"* → Terraform error surfaces, workflow fails red, diagnostics dump shows AWS-side error
- *"How do you handle a partial Terraform state corruption?"* → S3 lockfile + state encryption; if corruption, `terraform state rm` + re-import
- *"What's your rollback if bootstrap half-succeeds?"* → Workflow is idempotent — re-run picks up where it left off; or `terraform destroy` to start clean
- *"Why not use AWS CDK or Pulumi instead?"* → Terraform's wider ecosystem + cleaner state model for multi-cloud portability

---

## Q3: "What's the chicken-and-egg problem with OIDC + IRSA, and how did you solve it?"

**Round 1 — 2026-05-21 — Score: 5/10** (answered wrong chicken-and-egg — the runner one)
**Round 2 — 2026-05-21 — Score: 8.5/10** 🔒

**What Sai got right in R2:**
- ✅ Correctly distinguished 3 chicken-and-eggs (runner / IAM OIDC / IRSA ordering)
- ✅ Named `EntityAlreadyExists` error
- ✅ Cited exact code: `count = var.github_oidc_provider_arn == "" ? 1 : 0`
- ✅ Explained the "Terraform destroy left OIDC ARN" real-world scenario
- ✅ Listed full IRSA ordering chain (EKS → OIDC URL → IAM OIDC provider → IAM role → SA annotation)
- ✅ Named `depends_on` as the IRSA fix
- ✅ Closed with the 3-pattern synthesis: conditional run + dependency ordering + staged execution

**What to fix to reach 10/10:**
- "K8s API needs to connect to AWS" → more precise: **"Pods (via IRSA-annotated ServiceAccounts) need to call AWS APIs"**
- Cite specific commits: **Mar 22 `aab7a3a` and `2a9d93b`**
- Name **"global resource"** concept (IAM OIDC provider is global per account)
- Show staged execution explicitly: **"SA annotation happens in bootstrap AFTER Helm installs the SA — that's staged execution, separate from `depends_on`"**

**Ideal answer (~90 seconds spoken):**

> *"My project has three chicken-and-eggs related to authentication. The first is the runner — already discussed. Q3 is about the other two, both involving OIDC.*
>
> *Second problem: the IAM OIDC Identity Provider for GitHub Actions. My GitHub Actions workflows need to call AWS APIs — `aws eks describe-cluster`, `aws s3 ls`, etc. For AWS to accept GitHub Actions' identity, the OIDC provider must be registered in AWS IAM as a trusted issuer. The issue: OIDC providers are global resources in AWS — only one per account per URL. My first Terraform apply created it. When I partially destroyed resources or refactored state, Terraform tried to recreate it and AWS returned `EntityAlreadyExistsException`. My fix is the conditional create + reuse pattern: `count = var.github_oidc_provider_arn == "" ? 1 : 0`. If a variable provides the ARN — set via `TF_VAR_github_oidc_provider_arn` from a GitHub repository variable — Terraform skips creation and uses the existing one. If empty, Terraform creates. The locals block picks whichever is set. Commits `aab7a3a` and `2a9d93b` on March 22 fixed this.*
>
> *Third problem: IRSA ordering. Pods on EKS use IRSA to call AWS APIs — like S3 or DynamoDB — without static keys. The ordering is: EKS cluster must exist, which creates the cluster's OIDC issuer URL; then I register that URL as an OIDC provider in IAM; then I create an IAM role with a trust policy referencing that provider; then a Kubernetes ServiceAccount must be annotated with the IAM role ARN; only then can pods using that SA assume the role. Each step needs the previous one's output. Terraform's `depends_on` handles ordering inside the IaC layer — cluster first, then OIDC provider, then IAM role. The ServiceAccount annotation step is staged execution: it happens in the bootstrap workflow AFTER Helm installs the controller that creates the SA, because the SA doesn't exist until after Helm runs.*
>
> *The general principle: chicken-and-egg in infrastructure has three solution patterns — conditional create with reuse, explicit dependency ordering, and staged execution across separate stages. My bootstrap uses all three."*

**The 3 chicken-and-eggs reference:**
| # | Problem | Solution |
|---|---|---|
| 1 | Runner can't boot itself | GitHub-hosted job wakes self-hosted EC2 |
| 2 | IAM OIDC Provider already exists (global resource) | `count = var.X == "" ? 1 : 0` conditional create |
| 3 | IRSA ordering (EKS → OIDC → IAM → SA) | `depends_on` chains + staged execution |

**Secret weapon phrases:**
- *"Three chicken-and-eggs in this project, not one"*
- *"OIDC providers are global resources in AWS — only one per account per URL"*
- *"`EntityAlreadyExistsException` triggered the conditional create pattern"*
- *"Commits `aab7a3a` and `2a9d93b` on March 22 fixed this"*
- *"Three solution patterns: conditional create, dependency ordering, staged execution"*

**Likely hostile follow-ups:**
- *"How does the OIDC provider thumbprint stay current?"* → AWS auto-rotates; the thumbprint is GitHub's TLS cert SHA-1
- *"Why not use eksctl IRSA helper?"* → Terraform-native gives single source of truth + state tracking
- *"How do you handle adding a new IRSA-enabled service?"* → Add IAM role + trust policy in Terraform, annotate SA via `kubectl annotate` or manifest
- *"What if you migrate to a new AWS account?"* → Set `TF_VAR_github_oidc_provider_arn=""` in the new account → Terraform creates fresh

---

## Q5: "Your bootstrap is idempotent. Walk me through what happens on a re-run."

**Round 1 — 2026-05-21 — Score: 8.5/10** 🔒

**What Sai got right:**
- ✅ Opened with the 3 step types (declarative apply / preflight-guarded change / read-only check)
- ✅ Connected to March 22 marathon context (real experience grounding)
- ✅ Terraform idempotency correctly framed
- ✅ Toolchain drift framing on tooling installs
- ✅ Kubeconfig persistence via `$GITHUB_ENV` mentioned
- ✅ **Helm preflight cascade perfectly explained** (status check → rollback → uninstall → reinstall)
- ✅ **ALB webhook dry-run validation** with the nuke-and-reinstall fix
- ✅ Declarative `kubectl apply` framing
- ✅ Read-only check pattern (kubectl wait)
- ✅ Diagnostic dumps connected to `if: failure()` for safety

**What to fix to reach 9.5+/10:**
- Missed the **stuck namespace force-finalize** recovery pattern (3rd of 3)
- No **synthesizing closer**: "Every step either makes a deterministic change or is a no-op. No unguarded one-time actions."
- Could mention **concurrency control** as part of state coordination
- Small terminology: Helm states are `pending-install`/`pending-upgrade`/`pending-rollback` (not "pending or terminating")
- Argo CD detour — Argo CD isn't fully wired in the project, could mislead

**Ideal answer (~90 seconds spoken):**

> *"My bootstrap is idempotent by design — same result whether you run it once or a hundred times. Every step is one of three types: declarative apply, preflight-guarded change, or read-only check. No unguarded one-time actions.*
>
> *On a re-run: prepare-runner uses targeted Terraform apply — if resources already exist, Terraform sees no changes. Wake-up step starts the EC2 if stopped. Bootstrap job: full `terraform apply` is declarative, only applies the diff. `aws rds wait db-instance-available` returns immediately if RDS is up. Tooling installs are overwrites — fresh install every run to avoid toolchain drift. Kubeconfig saved to `$GITHUB_ENV` so all steps share it.*
>
> *Three recovery patterns. First, Helm preflight cascade: every Helm install wraps a status check. If release is `pending-install` or `pending-upgrade`, try `helm rollback`, if that fails do `helm uninstall`, then `helm upgrade --install`. Crashed Helm releases auto-recover. Second, ALB webhook dry-run validation: if `kubectl apply --dry-run=server` fails due to TLS cert corruption, nuke the webhook configurations and TLS secret, reinstall fresh. Third, stuck namespace force-finalize: if petclinic namespace is in `Terminating` state from a previous failed deploy, wait 5 min for natural cleanup, then force-finalize via `jq + kubectl replace --raw /finalize`. After cleanup, recreate.*
>
> *MySQL Secret fetches latest from Secrets Manager and applies — always converges. kubectl apply for Petclinic manifests is declarative — converges to desired state. Readiness checks are read-only. Diagnostic dumps run only on failure via `if: failure()` with `|| true` after each command.*
>
> *Workflow concurrency: `concurrency: terraform-${{ repository }}` with `cancel-in-progress: false` — only one Terraform workflow modifies state at a time.*
>
> *The synthesizing principle: every step either makes a deterministic change or is a no-op. No unguarded one-time actions. Idempotency was a design goal because cold-start paths fail in interesting ways — and re-runs need to safely recover from any partial state."*

**The 3 recovery patterns (memorize these):**
| # | Pattern | Where in your code |
|---|---|---|
| 1 | Helm preflight cascade | Lines 244-257 (ALB Controller install) |
| 2 | ALB webhook dry-run validation | Lines 408-453 |
| 3 | Stuck namespace force-finalize | Lines 459-479 |

**Secret weapon phrases:**
- *"Three step types: declarative apply, preflight-guarded change, read-only check"*
- *"Three recovery patterns: Helm preflight cascade, dry-run webhook validation, force-finalize stuck namespace"*
- *"`jq + kubectl replace --raw /finalize`"* (the force-finalize trick)
- *"Every step either makes a deterministic change or is a no-op"* (synthesizing closer)
- *"Idempotency was a design goal because cold-start paths fail in interesting ways"*

**Likely hostile follow-ups:**
- *"What if Terraform state lock is held by a dead workflow?"* → Manual `terraform force-unlock`, but very rare with workflow concurrency
- *"How do you know the recovery actually recovered?"* → Each recovery has its own success check (rollout status, dry-run validation)
- *"What if the underlying resource is corrupted in AWS, not just K8s?"* → Beyond bootstrap scope — would need manual investigation + targeted Terraform destroy/import

---

## Q2: "March 22, you had 20+ commits in one day. Tell me what was happening." (STAR)

**Round 1 — 2026-05-23 — Score: 8.5/10** 🔒

**What Sai got right:**
- ✅ Full STAR structure (Situation, Task, Action, Result, Lessons)
- ✅ Emotional honesty ("I was wrong" — sets up the journey)
- ✅ All 5 chapters with specific commit counts (5+5+4+3+2 = 19/20)
- ✅ Specific technical depth per bucket (OIDC, orphan TLS, STS expiration, force-finalize, runner paradox)
- ✅ **Killer line:** *"steps were implemented from the failed steps, not from the theory"*
- ✅ 3 lessons + bonus 4th on sequential ordering
- ✅ Concrete numbers throughout (15+ steps, 30 min, 20+ commits, 635 lines)

**What to fix to reach 9.5+/10:**
- Cite at least **2 specific commit hashes** (e.g., `aab7a3a` for OIDC, `c807b8f` for ALB webhook)
- Add the **"22 minutes"** final timing in the Result section
- Use the precise framing **"`terraform destroy` to fully running Petclinic"** (sets scale)

**Ideal answer (~2 min spoken):**

> *"By March 21, I had all the pieces working separately — Terraform, my runner, CI/CD, Helm charts. But I'd never run them end-to-end from zero. Bringing up the platform took 15+ manual steps and 30 minutes of focused attention.*
>
> *On March 22, I set out to build a one-click bootstrap that takes the platform from `terraform destroy` to fully running Petclinic. I expected a few hours. I was wrong. It took the whole day and 20+ commits.*
>
> *The day broke into five chapters of failures.*
>
> *First — AWS didn't know my CI's identity at the Kubernetes layer. My CI had AWS credentials, but `kubectl` returned 'Unauthorized' because EKS has its own access control. I added EKS Access Entries in Terraform to grant my role cluster admin. Also fixed an OIDC provider conflict where it already existed — commits `aab7a3a` and `2a9d93b`. And made kubeconfig persist via `$GITHUB_ENV` across workflow steps. Five commits.*
>
> *Second — the ALB Controller webhook nightmare. Helm crashes had left orphan TLS certificates, and every kubectl apply afterwards was rejected with cryptic errors. I added a preflight `kubectl apply --dry-run=server` check that detects the corruption, then nukes the webhook configs and TLS secret and reinstalls fresh — commit `c807b8f`. Plus IRSA annotation drift detection. Plus credential refresh mid-workflow because the bootstrap runs longer than the 1-hour STS lifetime. Five commits.*
>
> *Third — race conditions in the app deploy. Pods started before the MySQL Secret existed; pods crashed with 'secret not found.' I reordered: fetch from Secrets Manager → create K8s Secret → THEN kubectl apply pods. Also handled stuck namespaces by force-finalizing via `jq + kubectl replace --raw /finalize`. Four commits.*
>
> *Fourth — the destroy paradox. My destroy workflow ran on the self-hosted runner, but its job was to destroy that runner. The runner kept dying mid-workflow. Moved destroy to GitHub-hosted runners, made cleanup idempotent, added workflow concurrency so two terraform applies can't race on the state file. Three commits.*
>
> *Fifth — security hardening and polish. Two commits.*
>
> *By end of day, I had a 635-line bootstrap that runs reliably from `terraform destroy` to fully running Petclinic in 22 minutes — one click. Every recovery pattern in that workflow came from a specific failure I debugged that day, not from theory.*
>
> *Three takeaways. Cold-start paths reveal bugs that warm-start hides — every chicken-and-egg surfaces at once because nothing exists yet. Idempotency has to be designed in from the start, not retrofitted. And the 20+ commit messages from that day are essentially the runbook for the workflow — they document why every recovery step exists. Sequential ordering of operations is critical — it's not just what you do, it's what you do before what."*

**The 5-Chapter Memory Hook:** *"Identity → Certificates → Order → Paradox → Cleanup"*

| # | Chapter | Plain English |
|---|---|---|
| 1 | Identity | AWS didn't know CI for K8s |
| 2 | Certificates | ALB webhook TLS broken |
| 3 | Order | Race conditions (secrets, namespaces) |
| 4 | Paradox | Destroy workflow destroyed itself |
| 5 | Cleanup | Polish + security |

**Secret weapon phrases:**
- *"I was wrong"* — emotional setup
- *"From `terraform destroy` to fully running Petclinic"* — scale framing
- *"22 minutes"* — final timing
- *"Every recovery pattern came from a specific failure, not from theory"*
- *"20+ commit messages are essentially the runbook"*
- *"What you do before what"* — sequential ordering closer

**Likely behavioral follow-ups (this Q is gold for these too):**
- *"Tell me about a time you persevered through a difficult problem"* → same story
- *"What's a hard engineering day you'd rather forget?"* → same story
- *"Tell me about a time you debugged something for hours"* → same story
- *"How do you handle pressure?"* → "I broke the day into chapters, fixed each, moved forward"

---

## Q4: "ALB Webhook cert state kept getting stale. What was happening?"

**Round 1 — 2026-05-23 — Score: 8.5/10** 🔒

**What Sai got right:**
- ✅ Named both webhook types (mutating + validating)
- ✅ Specific Secret name: `aws-load-balancer-tls` + `caBundle` match
- ✅ Cluster-scoped vs namespace-scoped distinction (key insight)
- ✅ Full failure mode explained (Helm crashes → orphan TLS state)
- ✅ `kubectl apply --dry-run=server` as detection mechanism
- ✅ Full recovery cascade — all 5 components listed (webhook configs × 2, secret, service, deployment)
- ✅ IRSA annotation re-creation step
- ✅ Verification via re-running dry-run
- ✅ Synthesizing principle: *"detect with dry-run, nuke and re-install"*

**What to fix to reach 9.5+/10:**
- Add **"cluster was effectively locked"** consequence framing — makes impact visceral
- Cite commit hashes: **`c807b8f`** and **`ffdf556`**
- Mention **`--ignore-not-found`** flag for idempotent cleanup
- Tie to March 22 marathon context
- Minor: webhooks intercept **Services** (not "service accounts")

**Ideal answer (~90 seconds spoken):**

> *"The AWS Load Balancer Controller installs two admission webhooks — a mutating one and a validating one — that intercept Ingress and Service creates. They're TLS-protected: the cert lives in a Kubernetes Secret called `aws-load-balancer-tls` in kube-system, and the webhook configuration's `caBundle` field has to match.*
>
> *During my March 22 bootstrap marathon, I kept hitting this in different forms. The failure mode: when Helm crashed mid-install — network blip, timeout, OOM — the webhook configurations would stay in the cluster (they're cluster-scoped, not namespaced), but the TLS Secret or webhook service could be missing or empty. The configuration still pointed at the broken cert. Every subsequent `kubectl apply` against the cluster failed with a TLS verification error — even applying unrelated manifests, because both webhooks intercepted everything. The cluster was effectively locked.*
>
> *My fix is a two-step preflight pattern. Detection: I do a `kubectl apply --dry-run=server` against a tiny test Service manifest. Dry-run with `--server` triggers admission control without persisting, so if the webhook is broken, the dry-run fails. Recovery cascade: if detection fails, I delete everything related — both webhook configurations, the TLS secret, the webhook service, and the controller deployment, all with `--ignore-not-found` so it's idempotent. Then I recreate the ServiceAccount with the correct IRSA annotation and do `helm upgrade --install` to bring everything back fresh. New cert, new caBundle, all matching. Finally, I verify by re-running the same dry-run — if it passes, the webhook works.*
>
> *Commits `c807b8f` and `ffdf556` on March 22. The pattern: detect with dry-run, nuke and reinstall fresh. It works because every component that could be stale gets removed before the fresh install."*

**The Pattern Summary:**
| Step | What it does |
|---|---|
| 1. Detect | `kubectl apply --dry-run=server` against test Service |
| 2. Cascade delete | Both webhooks + TLS secret + webhook service + deployment (all `--ignore-not-found`) |
| 3. Reinstall SA | With correct IRSA annotation |
| 4. Reinstall controller | `helm upgrade --install` |
| 5. Verify | Re-run the dry-run |

**Secret weapon phrases:**
- *"Cluster was effectively locked"* (consequence framing)
- *"Cluster-scoped, not namespaced"* (why orphans survive)
- *"`--dry-run=server` triggers admission without persisting"*
- *"`--ignore-not-found` makes cleanup idempotent"*
- *"Detect with dry-run, nuke and reinstall"* (pattern summary)
- *"Commits `c807b8f` and `ffdf556`"* (receipts)

**Likely hostile follow-ups:**
- *"Why not just `helm uninstall` + `helm install`?"* → Helm doesn't always delete cluster-scoped webhook configurations on uninstall; explicit deletes are needed
- *"How do you know the dry-run actually exercises the webhook?"* → Mutating webhooks intercept Service creation; `--server` runs the full admission chain
- *"What about other webhooks (cert-manager, etc.)?"* → Same pattern applies; preflight detection generalizes

---

## Phase 4 — Trajectory (in progress)

| Question | R1 | R2 |
|---|---|---|
| Q1 — Walkthrough of bootstrap | **8.5/10** | — |
| Q2 — STAR story Mar 22 | **8.5/10** 🔒 | — |
| Q3 — OIDC + IRSA chicken-and-egg | 5/10 | **8.5/10** 🔒 |
| Q4 — ALB webhook stale state | **8.5/10** 🔒 | — |
| Q5 — Idempotent re-runs | **8.5/10** 🔒 | — |

**Phase 4 Average (Q1 + Q2 + Q3 R2 + Q5): 8.5/10 — strongest phase, 4 for 4 at 8.5/10.**

**Pattern:** Phase 4 questions have all hit 8.5/10 reliably. The 5-problem opening framework + 3-pattern frameworks (3 chicken-and-eggs, 3 step types, 3 recovery patterns, 5 STAR chapters) are landing reflexively.

**Behavioral bank value:** Q2 doubles as STAR material for "tell me about perseverance", "hardest day", "debugging story", "handling pressure" — same story, different framings.

---

## 📚 Phase 4 — Follow-up Answer Bank

Full ideal answers for every hostile follow-up across Q1-Q5.

---

### Q1 Follow-ups (Bootstrap orchestration)

**Q1.F1: "What if RDS provisioning fails?"**
> *"Terraform error surfaces in the workflow output with the AWS API error message. The workflow fails red at the `terraform apply` step. My `if: failure()` diagnostic dump captures the AWS-side error — subnet group misconfig, parameter group mismatch, KMS permission issue, etc. Recovery is reading the error, fixing the config, re-running. Idempotency: `terraform apply` is safe to re-run; existing resources are preserved, only the failed RDS creation retries. Most RDS failures are config errors, not transient AWS issues — fixing the config is the recovery."*

**Q1.F2: "How do you handle a partial Terraform state corruption?"**
> *"Three-layer defense. State is in S3 with versioning + KMS encryption — accidental delete recoverable via S3 version history. Locking via DynamoDB prevents concurrent state writes that cause corruption. For actual corruption: `terraform state rm <resource>` removes the corrupted entry; `terraform import <resource> <id>` re-imports from AWS. Critical: never edit state JSON by hand. Production rule: snapshot state to a different S3 bucket on every successful apply for point-in-time recovery."*

**Q1.F3: "What's your rollback if bootstrap half-succeeds?"**
> *"Workflow is idempotent — re-run picks up where it left off. Terraform's declarative model means re-applying converges to the desired state regardless of where the previous run failed. If the half-state is unsalvageable (e.g., orphaned resources, drift from spec), `terraform destroy` to start clean, then re-bootstrap. Average destroy + rebuild for my portfolio: ~25 min. Production trigger: any state where re-run can't reconcile cleanly."*

**Q1.F4: "Why not use AWS CDK or Pulumi instead?"**
> *"Three reasons for Terraform. One — broader provider ecosystem: Terraform supports Kubernetes, GitHub, Helm, Vault providers natively; CDK and Pulumi are AWS-first. Two — declarative state model: Terraform's state-then-plan-then-apply gives explicit drift detection; CDK's imperative TypeScript is harder to reason about. Three — portability: same Terraform works on AWS, GCP, Azure with provider swap. Tradeoff: HCL is less expressive than TypeScript/Python; CDK wins for complex computed configs. Production trigger to flip: monorepo with shared TypeScript libraries that need to share logic with infra."*

---

### Q2 Follow-ups (OIDC + IRSA chicken-and-egg)

**Q2.F1: "How does the OIDC provider thumbprint stay current?"**
> *"AWS auto-rotates the thumbprint. The IAM OIDC Identity Provider resource has a `thumbprint_list` that AWS validates against GitHub's TLS cert SHA-1 on every token exchange. When GitHub rotates the cert (rare, ~yearly), AWS detects the new cert and updates the thumbprint cache. For Terraform-managed providers, I use the `tls_certificate` data source to fetch the current thumbprint dynamically — no hardcoded value to maintain."*

**Q2.F2: "Why not use eksctl IRSA helper?"**
> *"Terraform-native gives single source of truth + state tracking. eksctl creates IRSA roles imperatively — fine for quick setup, but the roles aren't in Terraform state, so drift detection breaks. My infra has 15+ IRSA-related resources (provider, role, trust policy, role-policy attachments) — Terraform tracks all of them in one state file. Production rule: if it's infra, it's in Terraform."*

**Q2.F3: "How do you handle adding a new IRSA-enabled service?"**
> *"Four-step Terraform change. One — add IAM role in Terraform with trust policy referencing my existing OIDC provider ARN. Two — attach AWS-managed or custom policies for the service's required permissions. Three — annotate the K8s ServiceAccount with `eks.amazonaws.com/role-arn=<role-arn>` via manifest or kubectl. Four — restart the service's pods to pick up the new auth. All in one PR, deployed via terraform apply + kubectl apply. Production fix: codify the pattern as a Terraform module so each new IRSA-enabled service is 5 lines of config."*

**Q2.F4: "What if you migrate to a new AWS account?"**
> *"My conditional create pattern handles this. The Terraform module has `count = var.github_oidc_provider_arn == "" ? 1 : 0`. In a NEW account: set `TF_VAR_github_oidc_provider_arn=""` → Terraform creates a fresh OIDC provider. In an EXISTING account that already has one: set the var to the existing ARN → Terraform skips creation, reuses. Same Terraform, different env vars per account. Cross-account migration is a config change, not a code change."*

---

### Q3 Follow-ups (Bootstrap recovery patterns)

**Q3.F1: "What if Terraform state lock is held by a dead workflow?"**
> *"Manual `terraform force-unlock <lock-id>` — gets the lock ID from the error output, removes the DynamoDB entry. Risk: another active workflow loses its lock if you force-unlock prematurely. My workflow concurrency policy (`group: terraform-${{ github.repository }}, cancel-in-progress: false`) prevents this by making concurrent terraform runs WAIT instead of cancel — terraform processes complete cleanly even if a newer workflow is queued. Force-unlock is the emergency escape; concurrency policy is the prevention."*

**Q3.F2: "How do you know the recovery actually recovered?"**
> *"Each recovery step has its own success check. ALB Controller webhook recovery: `kubectl apply --dry-run=server` against a test Service — if it passes, the webhook is healthy. Argo CD install recovery: `kubectl rollout status deployment/argocd-server -n argocd` blocks until Ready. Namespace force-finalize: poll `kubectl get namespace petclinic` until it's gone. Every recovery step has an observable success criterion that the workflow gates on. No 'fire and pray' patterns."*

**Q3.F3: "What if the underlying resource is corrupted in AWS, not just K8s?"**
> *"Beyond bootstrap scope — would need manual investigation + targeted action. Example: corrupted RDS storage requires AWS support ticket + restore from snapshot. Corrupted EKS control plane requires AWS support. For things bootstrap can handle (corrupted K8s state from a failed Helm install, stuck namespaces with finalizers), the preflight detection + force-recovery pattern works. For AWS-side corruption, the recovery is `terraform destroy` + rebuild from snapshots, which my portfolio scope accepts."*

---

### Q4 Follow-ups (ALB Controller preflight recovery)

**Q4.F1: "Why not just `helm uninstall` + `helm install`?"**
> *"Helm doesn't always delete cluster-scoped webhook configurations on uninstall — they're namespace-independent and Helm's RBAC may not have permission. So after `helm uninstall`, the webhook configs (Mutating/Validating) can remain, intercepting future installs and failing with TLS errors. My recovery explicitly deletes the webhook configs by name with `--ignore-not-found` before reinstall, plus the TLS Secret, plus the Service. Explicit cleanup of cluster-scoped resources is the lesson from commit `c807b8f`."*

**Q4.F2: "How do you know the dry-run actually exercises the webhook?"**
> *"`kubectl apply --dry-run=server` runs the full admission chain — including all mutating and validating webhooks. The `--server` flag (vs `--client`) means the apiserver processes the request, hitting the webhook endpoints. If the webhook is broken (cert expired, endpoint unreachable), dry-run returns a TLS or connection error. I use this against a test Service manifest as my preflight check — if the dry-run succeeds, the webhook is healthy enough to run real applies."*

**Q4.F3: "What about other webhooks (cert-manager, etc.)?"**
> *"Same pattern applies — preflight check via dry-run, detect corruption, force-delete webhook configs + dependent resources, fresh install. cert-manager has the same fragility (its TLS Secret can go stale). I'd generalize the recovery script: takes the controller name as parameter, deletes its namespaced resources + cluster-scoped webhooks, calls helm install. The preflight + force-recovery pattern is broadly applicable to any admission webhook installation."*

---
