# Phase 4 — Bootstrap Stabilization Marathon (COMPLETE REFERENCE)

**Window:** March 22, 2026 (ONE DAY, 20+ commits)
**Final Average Score:** **8.5/10** across **5 hostile interview questions** — your strongest phase
**Status:** ✅ Locked — interview-winning territory

This is your **complete reference** for Phase 4. Everything covered in training is captured here.

---

## 📑 Table of Contents

1. [Phase 4 Vocabulary (Memorize These Terms)](#vocabulary)
2. [The Story (Why / What / Fails / Wins)](#the-story)
3. [Architecture Decisions Explained](#architecture-decisions)
4. [The 5 Chapters of the March 22 Marathon](#the-5-chapters)
5. [`infra-bootstrap.yaml` Complete Walkthrough](#bootstrap-walkthrough)
6. [Foundation Concepts](#foundation-concepts)
7. [5 Hostile Q&A (Drilled — Summaries)](#hostile-qa)
8. [Power Phrases & Secret Weapons](#power-phrases)
9. [Common Mistakes to Avoid](#common-mistakes)
10. [Cheat Card](#cheat-card)

---

<a name="vocabulary"></a>
## 1. Phase 4 Vocabulary (Memorize These Terms)

These are the specific words you need to drop in Phase 4 interview answers. Each one is a senior signal.

### Bootstrap & Workflow Patterns

| Term | Definition | Where it's used |
|---|---|---|
| **Cold-start path** | Bringing up a system from zero state — nothing exists yet | Bootstrap workflow purpose |
| **Bootstrap paradox** | Can't destroy what you're running on / can't boot what boots you | Self-hosted runner needs GitHub-hosted to wake it; destroy can't run on the runner being destroyed |
| **Idempotency** | Same result whether run once or 100 times — re-runs are safe | Q5 design principle |
| **Targeted Terraform apply** | `terraform apply -target=resource` to create a subset of resources | Prepare-runner job |
| **Chicken-and-egg** | A needs B, B needs A — neither can be created without the other | Three of them: runner, IAM OIDC, IRSA ordering |
| **Conditional create + reuse** | `count = var.X == "" ? 1 : 0` — create if not present, use existing if available | OIDC provider fix |
| **Staged execution** | Splitting operations into separate stages because they can't happen in one apply | SA annotation after Helm install |
| **State coordination** | Workflow concurrency to prevent parallel terraform runs from corrupting state | `concurrency: terraform-${{ repo }}` |

### Helm & Recovery Patterns

| Term | Definition | Where it's used |
|---|---|---|
| **Helm release** | Single Helm install lifecycle with its own version history | All Helm-installed tools |
| **`pending-install` / `pending-upgrade`** | Helm release stuck mid-operation (usually from crash) | The state preflight checks detect |
| **Preflight cascade** | Detect bad state → try rollback → fall back to uninstall → fresh install | Helm install pattern |
| **`helm rollback`** | Revert release to previous successful revision | First step of cascade |
| **Orphan TLS state** | Webhook configuration exists but TLS cert is missing/stale | ALB webhook issue |
| **`--ignore-not-found`** | kubectl flag that makes delete commands idempotent (no error if missing) | Recovery cascades |
| **`--atomic`** | Helm flag for auto-rollback on install failure | Helm best practice |
| **`workflow_run: completed`** | GitHub Actions trigger for workflow chaining | e2e-smoke chains to bootstrap |

### EKS, IAM, OIDC

| Term | Definition | Where it's used |
|---|---|---|
| **EKS Access Entries** | Modern API (replaces aws-auth ConfigMap) for granting IAM principals K8s access | Bootstrap registers CI role |
| **`AmazonEKSClusterAdminPolicy`** | AWS-managed access policy granting cluster-wide admin | What CI's role gets |
| **IRSA** | IAM Roles for Service Accounts — pods assume IAM roles via OIDC | ALB Controller pattern |
| **OIDC Identity Provider** | AWS IAM resource registering a trusted token issuer | GitHub Actions auth + EKS IRSA |
| **OIDC issuer URL** | EKS cluster's unique identity-issuing endpoint | `https://oidc.eks.us-east-1.amazonaws.com/id/ABC` |
| **ServiceAccount (SA)** | K8s pod identity, optionally annotated with IRSA role | `aws-load-balancer-controller` SA |
| **STS** | AWS Security Token Service — issues temporary 1-hour credentials | OIDC federation gives these |
| **STS credential refresh** | Re-authenticating mid-workflow to avoid expired credentials | Long workflows >1 hour |

### Kubernetes Admission & TLS

| Term | Definition | Where it's used |
|---|---|---|
| **Admission webhook** | K8s extensibility — code that runs before resources are stored | ALB Controller uses two |
| **MutatingWebhookConfiguration** | Webhook that can MODIFY resources during admission | ALB injects AWS-specific fields |
| **ValidatingWebhookConfiguration** | Webhook that can REJECT resources during admission | ALB validates Ingress configs |
| **`caBundle`** | Certificate Authority bundle the API server uses to verify webhook TLS | Must match the cert in the Secret |
| **`kubectl apply --dry-run=server`** | Send manifest through admission control without persisting | Used to detect broken webhook |
| **Cluster-scoped resource** | K8s resource that lives outside any namespace (e.g., webhook configs) | Why they survive Helm rollback |
| **Stuck namespace ("Terminating")** | Namespace in delete state but blocked by finalizers | Force-finalize via `jq + kubectl replace --raw /finalize` |
| **`/api/v1/namespaces/X/finalize`** | The K8s API endpoint for force-finalizing namespace | The "magic command" |

### Failure Modes & Diagnostics

| Term | Definition | Where it's used |
|---|---|---|
| **`EntityAlreadyExistsException`** | AWS error when trying to create something that exists | OIDC provider chicken-and-egg trigger |
| **`ImagePullBackOff`** | K8s error: can't pull a container image | What happens if manifest references missing tag |
| **`if: failure()`** | GitHub Actions condition — step only runs if previous failed | Diagnostic dump pattern |
| **`|| true`** | Bash shorthand to ignore errors and continue | Used in cleanup chains |
| **Partial-success state** | System half-applied — some resources created, others failed | Bootstrap recovery scenarios |
| **Defensive idempotency** | `git commit ... || echo "No changes"` — turn failure into safe no-op | `updatek8s` pattern |

### Communication & Soft Phrases

| Phrase | When to use |
|---|---|
| *"Cluster was effectively locked"* | Visceral consequence framing for webhook failure |
| *"Every recovery pattern came from a specific failure, not from theory"* | The killer line for STAR story |
| *"Identity → Certificates → Order → Paradox → Cleanup"* | 5-chapter memory hook for Mar 22 |
| *"Detect with dry-run, nuke and reinstall"* | Synthesizing principle for webhook fix |
| *"Three step types: declarative apply, preflight-guarded change, read-only check"* | Idempotency framework |
| *"Three solution patterns: conditional create, depends_on, staged execution"* | Chicken-and-egg framework |

---

<a name="the-story"></a>
## 2. The Story (Why / What / Fails / Wins)

### Why Phase 4 Existed

By March 21, you had all the pieces working independently:
- ✅ Terraform creating EKS, VPC, RDS
- ✅ Self-hosted runner (Phase 3)
- ✅ CI pipeline for api-gateway
- ✅ Helm charts for ALB Controller, Prometheus

**But nothing wired them together end-to-end.** Bringing up the platform from scratch required 15+ manual steps and 30 minutes.

Phase 4 answered: ***"How do I go from `terraform destroy` to fully running Petclinic with ONE click?"***

The senior answer: **a bootstrap workflow that's idempotent, ordered, and recovers from every common failure mode.**

### The Fails (the Marathon)

20+ commits on March 22, breaking into 5 chapters:
1. **Identity** (5 commits) — OIDC + EKS access + kubeconfig persistence
2. **Certificates** (5 commits) — ALB Controller webhook TLS + IRSA + creds refresh
3. **Order** (4 commits) — race conditions + stuck namespaces
4. **Paradox** (3 commits) — destroy workflow + concurrency
5. **Cleanup** (2 commits) — security hardening + polish

### The Wins

By end of day:
- ✅ **635-line workflow** that runs from `terraform destroy` to fully running Petclinic in **~22 minutes**
- ✅ **Idempotent** — safe to re-run on any failure
- ✅ **Self-healing** — preflight checks for ALB webhook, Helm states, stuck namespaces
- ✅ **Defensive** — diagnostic dumps via `if: failure()` for 2 AM debugging
- ✅ **Chained** — automatically triggers `e2e-smoke.yaml` on success
- ✅ **Coordinated** — workflow concurrency prevents state corruption

---

<a name="architecture-decisions"></a>
## 3. Architecture Decisions Explained

### Why the Two-Job Architecture

**Job 1: prepare-runner** on GitHub-hosted runner (Ubuntu)
- Wakes up the self-hosted EC2 runner (if stopped by cost crons)
- Solves the chicken-and-egg: can't use a runner that doesn't exist

**Job 2: bootstrap** on self-hosted runner (inside VPC)
- Full Terraform apply, Helm installs, Petclinic deploy
- Needs to reach private EKS endpoint → must be inside VPC

### Why `concurrency: cancel-in-progress: false`

If a second bootstrap is triggered while one is running:
- `cancel-in-progress: true` would KILL the running terraform mid-apply → state corruption
- `cancel-in-progress: false` makes the second one WAIT politely → safe serialization

### Why "Targeted Terraform Apply" for the Runner

Full `terraform apply` would try to create EKS too — but EKS API is private. The runner doesn't exist yet to reach it. So:
- prepare-runner does `terraform apply -target=runner_resources` only
- Once runner exists, full apply runs from inside the VPC

### Why "GitHub-Hosted for Destroy"

The destroy workflow needs to destroy the self-hosted runner. You can't destroy the thing you're running on. So destroy runs on GitHub-hosted runners — they outlive the resources being destroyed.

---

<a name="the-5-chapters"></a>
## 4. The 5 Chapters of the March 22 Marathon

### Chapter 1: Identity (5 commits — ~3 hours)

**Commits:** `aab7a3a`, `2a9d93b`, `a2beae8`, `526a68b`, `aad7399`

**Problem 1:** Terraform tried to create OIDC provider that already existed → `EntityAlreadyExistsException`.
**Fix:** `count = var.X == "" ? 1 : 0` conditional create pattern.

**Problem 2:** CI's IAM role wasn't in EKS Access Entries → kubectl "Unauthorized".
**Fix:** Added access entries in Terraform.

**Problem 3:** Each workflow step had fresh shell → kubeconfig lost between steps.
**Fix:** Save to `$RUNNER_TEMP/kubeconfig`, export via `$GITHUB_ENV`.

### Chapter 2: Certificates (5 commits — ~4 hours)

**Commits:** `ffdf556`, `737952a`, `c807b8f`, `a05abd5`, `62b7759`

**Problem 1:** Helm crash left orphan TLS cert state — every kubectl apply failed with cryptic errors.
**Fix:** Preflight `kubectl apply --dry-run=server` detection + nuke-and-reinstall cascade.

**Problem 2:** IRSA annotation on SA drifted after Helm reinstall.
**Fix:** Compare actual vs desired, repair if needed.

**Problem 3:** STS credentials expired during 20+ min bootstrap.
**Fix:** Added "Refresh AWS credentials before readiness checks" step.

### Chapter 3: Order (4 commits — ~3 hours)

**Commits:** `f95d15b`, `11abbb7`, `3aeedb7`, `7b4a357`

**Problem 1:** Malformed YAML in deployment manifests.
**Fix:** Cleaned up, validated.

**Problem 2:** Pods started before MySQL Secret existed.
**Fix:** Reordered: namespace → fetch secret from Secrets Manager → create K8s Secret → THEN apply pods.

**Problem 3:** `petclinic` namespace stuck in `Terminating` state from previous failed deploy.
**Fix:** Wait for cleanup; if stuck, force-finalize via `jq + kubectl replace --raw /finalize`.

### Chapter 4: Paradox (3 commits — ~1 hour)

**Commits:** `8dfeb7d`, `82f6812`, `d34bf20`

**Problem 1:** Destroy workflow on self-hosted runner = destroying the runner you're running on.
**Fix:** Moved destroy to GitHub-hosted runners.

**Problem 2:** Destroy could fail partway, leaving orphan resources.
**Fix:** Made cleanup steps idempotent (tolerate "already gone" errors).

**Problem 3:** Two terraform applies in parallel would corrupt state.
**Fix:** Added `concurrency: { group: terraform-${{ repo }}, cancel-in-progress: false }`.

### Chapter 5: Cleanup (2 commits)

**Commits:** `1c12b7e`, `18827fd`

Pod security context (Phase 2 work) + api-gateway UI update.

---

<a name="bootstrap-walkthrough"></a>
## 5. `infra-bootstrap.yaml` Complete Walkthrough

**Size:** 635 lines, ~22 minutes end-to-end.

**Structure:**
- Trigger: `workflow_dispatch` (manual)
- Concurrency: `terraform-${{ github.repository }}` with `cancel-in-progress: false`
- Two jobs: `prepare-runner` (GitHub-hosted) and `bootstrap` (self-hosted)

**Major bootstrap steps (in order):**
1. Checkout + OIDC auth + Terraform setup
2. Confirm runner healthy
3. `terraform apply` full stack (~15 min)
4. `aws rds wait db-instance-available`
5. Install tooling (kubectl, eksctl, helm)
6. Configure kubeconfig + persist via `$GITHUB_ENV`
7. Verify CloudWatch observability add-ons
8. Install ALB Controller via Helm (with preflight cascade)
9. Wait for ALB Controller webhook
10. Install Argo CD (with state recovery)
11. Install Argo Rollouts
12. Install kubectl argo rollouts plugin
13. Install Prometheus + Grafana
14. Verify Prometheus stack
15. Verify ALB Controller IRSA (compare + repair)
16. Validate ALB webhook TLS (dry-run + cascade)
17. Deploy Petclinic workloads (with namespace recreation + secret bridge)
18. Verify CloudWatch log groups
19. Verify ServiceMonitors
20. Refresh AWS credentials (STS expiry)
21. Refresh kubeconfig
22. Readiness checks (all rollouts + ALB hostname)
23. Verify Prometheus scrape targets
24. Verify api-gateway Prometheus metrics
25. Diagnostic dumps (if failure)

**Triggers on success:** `e2e-smoke.yaml` via `workflow_run: completed`

---

<a name="foundation-concepts"></a>
## 6. Foundation Concepts (New in Phase 4)

(All covered in detail in [Vocabulary](#vocabulary) section. Key ones:)

- Cold-start path
- Bootstrap paradox
- Idempotency (3 step types: declarative / preflight-guarded / read-only)
- Chicken-and-egg (3 of them in this project)
- 3 solution patterns: conditional create, dependency ordering, staged execution
- 3 recovery patterns: Helm preflight cascade, dry-run webhook validation, stuck namespace force-finalize
- Admission webhooks + TLS + caBundle
- EKS Access Entries (modern aws-auth replacement)
- STS credential refresh mid-workflow
- Workflow concurrency for state coordination

---

<a name="hostile-qa"></a>
## 7. 5 Hostile Q&A (Drilled — Summaries)

Full Q&As with ideal answers, secret weapons, and follow-ups live in **[phase-4-qa.md](phase-4-qa.md)**.

| Q | Question | Score | Key insight |
|---|----------|-------|-------------|
| **Q1** | "Walk me through your infra-bootstrap workflow" | **8.5** | Opens with **5-problem framing**: sequencing, concurrency, idempotency, stale recovery, auth expiration, diagnostics |
| **Q2** | "March 22, 20+ commits — tell me what happened" (STAR) | **8.5** | **5 chapters**: Identity → Certificates → Order → Paradox → Cleanup |
| **Q3** | "OIDC + IRSA chicken-and-egg" | **8.5** (R2) | **3 chicken-and-eggs**: runner / IAM OIDC / IRSA ordering. **3 solution patterns**: conditional create, dependency ordering, staged execution |
| **Q4** | "ALB webhook stale state" | **8.5** | **Detect with dry-run, nuke and reinstall fresh.** TLS cert + caBundle mismatch story |
| **Q5** | "Idempotent re-run walkthrough" | **8.5** | **3 step types**: declarative / preflight-guarded / read-only. Every step is a no-op or a deterministic change |

**Phase 4 Average: 8.5/10 — your strongest phase.**

---

<a name="power-phrases"></a>
## 8. Power Phrases & Secret Weapons

### Bootstrap / Operational Maturity
- ✨ **"From `terraform destroy` to fully running Petclinic in 22 minutes — one click"**
- ✨ **"635 lines"** (scale signal)
- ✨ **"Every recovery pattern came from a specific failure, not from theory"**
- ✨ **"20+ commit messages are essentially the runbook"**
- ✨ **"Bootstrap paradox: can't boot what boots you / can't destroy what you're running on"**
- ✨ **"Cold-start paths reveal bugs that warm-start hides"**

### Idempotency
- ✨ **"Three step types: declarative apply, preflight-guarded change, read-only check"**
- ✨ **"Every step either makes a deterministic change or is a no-op"**
- ✨ **"No unguarded one-time actions"**
- ✨ **"Idempotency was a design goal because cold-start paths fail in interesting ways"**

### Chicken-and-Egg
- ✨ **"Three chicken-and-eggs in this project, not one"**
- ✨ **"Three solution patterns: conditional create, dependency ordering, staged execution"**
- ✨ **"`count = var.X == "" ? 1 : 0` — conditional create + reuse"**
- ✨ **"OIDC providers are global resources in AWS — only one per account per URL"**

### Webhook Recovery
- ✨ **"Cluster was effectively locked — every kubectl apply was failing"**
- ✨ **"Cluster-scoped resources survive Helm rollback — that's why orphans accumulate"**
- ✨ **"`--dry-run=server` triggers admission without persisting"**
- ✨ **"Detect with dry-run, nuke and reinstall fresh"**
- ✨ **"`--ignore-not-found` makes cleanup idempotent"**

### Mar 22 STAR Story
- ✨ **"I was wrong"** — emotional setup
- ✨ **"Identity → Certificates → Order → Paradox → Cleanup"** — 5-chapter memory hook
- ✨ Commits **`aab7a3a`, `c807b8f`** — receipts
- ✨ **"What you do before what"** — sequential ordering closer

---

<a name="common-mistakes"></a>
## 9. Common Mistakes to Avoid

| Mistake | Why it hurts |
|---|---|
| Answering Q3 with the runner chicken-and-egg only | The question asks about OIDC+IRSA specifically — 3 different problems |
| Saying *"random TLS error"* for webhook issue | Sounds clueless — you DEBUGGED it; explain the mechanism |
| Conflating EKS Access Entries with IAM permissions | IAM is AWS-layer auth; Access Entries is K8s-layer auth — both needed |
| Saying *"Helm has pending or terminating mode"* | States are `pending-install`/`pending-upgrade`/`pending-rollback` (no "terminating") |
| Forgetting commit hashes when asked for proof | `aab7a3a`, `c807b8f` are receipts that prove you lived it |
| Mentioning Argo CD as if it's wired up for petclinic | Argo CD is installed but not actively managing petclinic services yet |
| Saying "EC2 destroys itself" without naming it as a paradox | The framing "bootstrap paradox" is the senior signal |

---

<a name="cheat-card"></a>
## 10. Cheat Card (One-Page Summary)

### Phase 4 Architecture
```
[YOU click "Run workflow"]
       ↓
┌───────────────────────────────────────────────────────────┐
│  prepare-runner (GitHub-hosted)                            │
│  • Targeted Terraform apply for VPC + runner only         │
│  • Wake up EC2 runner if stopped                          │
└────────────────────┬──────────────────────────────────────┘
                     ↓
┌───────────────────────────────────────────────────────────┐
│  bootstrap (self-hosted, inside VPC)                       │
│                                                            │
│  ├── Terraform full apply (~15 min)                       │
│  ├── Wait for RDS available                                │
│  ├── Install tooling (kubectl, eksctl, helm)              │
│  ├── Configure kubeconfig + persist via $GITHUB_ENV       │
│  ├── Helm install ALB Controller                          │
│  │   └── Preflight cascade for pending-install states    │
│  ├── Validate ALB webhook (dry-run + nuke/reinstall)      │
│  ├── Helm install Argo CD, Argo Rollouts, Prometheus      │
│  ├── Refresh STS credentials                              │
│  ├── Handle stuck petclinic namespace                     │
│  ├── Pull RDS creds from Secrets Manager → K8s Secret    │
│  ├── kubectl apply Petclinic services                    │
│  ├── Readiness checks (rollouts + ALB hostname)           │
│  └── Diagnostic dumps on failure                          │
└────────────────────┬──────────────────────────────────────┘
                     ↓
              [workflow succeeds]
                     ↓
┌───────────────────────────────────────────────────────────┐
│  e2e-smoke.yaml triggers automatically                     │
│  (via `workflow_run: completed` chain)                    │
└───────────────────────────────────────────────────────────┘
```

### Key Numbers
- **Lines:** 635 (bootstrap workflow)
- **Time:** ~22 minutes end-to-end
- **Commits Mar 22:** 20+
- **STS lifetime:** 1 hour (forced credential refresh)
- **Petclinic services deployed:** 6 (api-gateway, customers, vets, visits, discovery, config)
- **Helm charts installed:** 4 (ALB Controller, Argo CD, Argo Rollouts, kube-prometheus-stack)

### The 4 Frameworks (memorize these)
| Framework | Components |
|---|---|
| **5 problems** | Sequencing, concurrency, idempotency, stale recovery, auth expiration, diagnostics |
| **3 step types** | Declarative apply / preflight-guarded change / read-only check |
| **3 chicken-and-eggs** | Runner / IAM OIDC / IRSA ordering |
| **3 solution patterns** | Conditional create / dependency ordering / staged execution |
| **3 recovery patterns** | Helm preflight cascade / dry-run webhook validation / stuck namespace force-finalize |
| **5 STAR chapters** | Identity → Certificates → Order → Paradox → Cleanup |

### Interview Q Score Targets
| Question Type | Target |
|---|---|
| Bootstrap walkthrough | 8.5+ |
| STAR story Mar 22 | 8.5+ |
| OIDC + IRSA chicken-and-egg | 8+ |
| ALB webhook recovery | 8+ |
| Idempotency walkthrough | 8.5+ |

---

## Phase 4 — COMPLETE ✅

**Average score across 5 questions: 8.5/10 — your strongest phase, interview-winning at $120-165K band.**

Next: **Phase 5 — Argo Rollouts Canary** (the deployment showcase story)
