# Phase 5 — Argo Rollouts Canary Deployment (COMPLETE REFERENCE)

**Window:** Mar 22 → Mar 24, 2026 (~3 days, ~10 commits)
**Final Average Score:** **7.5/10** across **5 hostile interview questions**
**Status:** ✅ Locked — interview-viable

This is your **complete reference** for Phase 5. Everything covered in training is captured here.

---

## 📑 Table of Contents

1. [Phase 5 Vocabulary (Memorize These Terms)](#vocabulary)
2. [The Story (Why / What / Fails / Wins)](#the-story)
3. [Architecture Decisions Explained](#architecture-decisions)
4. [The 4 Canary Steps Walkthrough](#the-4-steps)
5. [Code Walkthrough — `deploy.yaml` + `analysis-template.yaml` + `api-gateway-canary.yaml`](#code-walkthrough)
6. [Foundation Concepts](#foundation-concepts)
7. [5 Hostile Q&A (Drilled — Summaries)](#hostile-qa)
8. [Power Phrases & Secret Weapons](#power-phrases)
9. [Common Mistakes to Avoid](#common-mistakes)
10. [Cheat Card](#cheat-card)

---

<a name="vocabulary"></a>
## 1. Phase 5 Vocabulary (Memorize These Terms)

These are the specific terms you need to drop in Phase 5 interview answers.

### Argo Rollouts CRDs

| Term | Definition | Where used |
|---|---|---|
| **Rollout** (`kind: Rollout`) | Argo Rollouts CRD that replaces standard `Deployment`. Supports canary + blue-green strategies. | `api-gateway/deploy.yaml` |
| **AnalysisTemplate** | CRD defining metric queries to validate a canary | `analysis-template.yaml` |
| **AnalysisRun** | An INSTANCE of running an AnalysisTemplate (created per rollout attempt) | Debugging failed analysis |
| **Argo Rollouts controller** | Cluster pod that reconciles Rollout specs (installed in `argo-rollouts` namespace) | Phase 4 bootstrap installs it |
| **`setWeight`** | Rollout step that shifts traffic % to canary | `setWeight: 20` |
| **`pause: { duration: Nm }`** | Timed pause — auto-resumes | Pre-analysis data collection |
| **`pause: {}`** | INDEFINITE pause — waits forever for human | Manual approval gate |
| **`failureLimit`** | How many metric failures abort the rollout | `failureLimit: 1` (strict) |
| **`interval` + `count`** | How often + how many times to run a metric query | `interval: 1m, count: 3` |

### Traffic Management

| Term | Definition | Where used |
|---|---|---|
| **3-service pattern** | Stable + canary + root Services for canary routing | api-gateway-stable / api-gateway-canary / api-gateway |
| **`trafficRouting.alb`** | Rollout's ALB integration via AWS Load Balancer Controller | `deploy.yaml` line 24-28 |
| **TargetGroupBinding** | AWS Load Balancer Controller CRD bridging K8s Services to ALB target groups | Used by trafficRouting.alb |
| **rootService** | The Service the Ingress points at; receives all traffic, splits between stable/canary | `api-gateway` |
| **stableService** | Service routing to current-version pods | `api-gateway-stable` |
| **canaryService** | Service routing to new-version pods | `api-gateway-canary` |

### Prometheus & PromQL

| Term | Definition | Where used |
|---|---|---|
| **`http_server_requests_seconds_count`** | Spring Boot Micrometer metric — request counter by status code | Both PromQL queries |
| **`status!~"5.."`** | PromQL regex: "status does NOT match 5xx pattern" | Success rate query |
| **`status=~"5.."`** | PromQL regex: "status MATCHES 5xx pattern" | 5xx rate query |
| **`rate(...[2m])`** | Per-second rate of counter over 2 min window | Both queries |
| **`sum(rate(...))`** | Aggregate rate across all canary pods | Both queries |
| **`clamp_min(..., 0.001)`** | Prevents division-by-zero when no canary traffic yet | Both denominators |

### Rollback & Recovery

| Term | Definition | Where used |
|---|---|---|
| **`kubectl argo rollouts promote api-gateway`** | Advance past manual pause to next step | After Grafana review |
| **`kubectl argo rollouts abort api-gateway`** | Manually abort and shift traffic back to 100% stable | Emergency rollback |
| **`kubectl argo rollouts get api-gateway`** | View current rollout state, step, abort reason | Debugging |
| **`kubectl argo rollouts get api-gateway -w`** | WATCH live (refreshes status) | Live monitoring |
| **Degraded status** | Rollout marked failed (auto-aborted or manually aborted) | Status reporting |
| **`progressDeadlineSeconds`** | How long rollout can be "stalled" before marked failed | `600` in your spec |
| **`revisionHistoryLimit`** | Number of previous Rollout revisions kept for fast rollback | `3` in your spec |
| **`rollbackWindow`** | Configurable lookback for fast manual rollback | `{ revisions: 3 }` |

### Workflow Mechanics

| Term | Definition | Where used |
|---|---|---|
| **`verify-infra-bootstrap`** | Gate job that checks last bootstrap succeeded before deploying | api-gateway-canary.yaml job 1 |
| **`workflow_dispatch`** | Manual trigger via GitHub UI button | Alternative trigger |
| **`push: branches: [main]`** | Auto-trigger when main branch is updated | Primary trigger |
| **`paths: kubernetes/api-gateway/**`** | Path filter — only trigger when api-gateway manifests change | Trigger refinement |
| **`concurrency: api-gateway-production`** | Workflow concurrency group preventing parallel canary deploys | Top of api-gateway-canary.yaml |

### Communication Phrases

| Phrase | When to use |
|---|---|
| *"Progressive delivery"* | Canary's defining concept |
| *"5x blast radius reduction"* | Quantify canary's value |
| *"Old stable pods were never scaled down"* | Why rollback is fast |
| *"Trust through verification"* | Manual gate philosophy |
| *"Two-layer defense"* | Automated + human signaling |
| *"GOOD ≥ 95%, BAD ≤ 1%"* | Threshold mnemonic |

---

<a name="the-story"></a>
## 2. The Story (Why / What / Fails / Wins)

### Why Phase 5 Existed

After Phase 4, your CI/CD pipeline was functional:
- ✅ CI built, scanned, pushed images
- ✅ Bootstrap deployed everything
- ✅ Petclinic services ran as standard Kubernetes Deployments

**But every deploy was "all or nothing."** A bad image → 100% of users immediately impacted.

CI/CD static checks (SonarCloud, Trivy, JaCoCo) catch CODE issues but can't catch RUNTIME regressions:
- Memory leaks under real traffic
- 5xx error spikes at scale
- Latency degradation
- Production-only bugs (real DB load, external API timing)

**You needed runtime validation BEFORE 100% rollout.** That's canary.

Phase 5 answered: ***"How do I catch bad images at 20% traffic instead of 100%, with automated rollback when regression is detected?"***

The senior answer: **Argo Rollouts with Prometheus-driven AnalysisTemplate.**

### The Fails (~10 commits)

| Date | Commit | What broke |
|---|---|---|
| Mar 22 | `1223fbf` | "canary deployment changes" — initial implementation |
| Mar 22 | `0a36aa8` | "duplicate EKS access entry creation fix" |
| Mar 22 | `0aca7d4` | "bad readiness check in the workflow fix" |
| Mar 23 | `7ae8d5a` | "chore: update api-gateway image tag for canary rollout" |
| Mar 23 | `a9f2464` | "rollback issue verification" — tested abort path |
| Mar 23 | `cdfe413` | "added workflow dispatch to canary" — manual trigger |
| Mar 24 | `94091b1` | "canary deployment based on metrics changes" — refined PromQL queries |
| Mar 24 | `735711c` | "ci: gate canary deploy on infra-bootstrap success" — added the verify gate |

**Honest interview tells:**
- *"My first canary attempt didn't have the bootstrap-success gate — I deployed canary to a half-broken cluster and analysis failed. Added the verify-infra-bootstrap job."*
- *"My Prometheus queries initially used 1m windows which had no data on a freshly-deployed canary. Bumped to 2m windows for meaningful averages."*
- *"I deliberately deployed a broken image to test the rollback path. Watched Argo Rollouts abort at 20% traffic — confirmed the safety net works."*

### The Wins

By March 24:
- ✅ api-gateway runs as Argo Rollout with canary strategy
- ✅ 3-service pattern (stable/canary/root) integrated with ALB
- ✅ Prometheus AnalysisTemplate with 2 metrics (success rate + 5xx rate)
- ✅ 20% → analysis → manual approval gate workflow
- ✅ Companion canary workflow gated on bootstrap success
- ✅ Tested abort path — automatic rollback when metrics fail
- ✅ Manual promote via `kubectl argo rollouts promote api-gateway`

---

<a name="architecture-decisions"></a>
## 3. Architecture Decisions Explained

### Why Canary Over Blue-Green

**Three reasons:**
1. **Cost** — Blue-Green doubles infrastructure during deploy window; doesn't fit $20/mo budget
2. **Blast radius** — Canary catches issues at 20% traffic (5x reduction vs 100% blue-green cutover)
3. **Automated analysis** — Prometheus AnalysisTemplate at intermediate traffic weights fits naturally with canary

**Tradeoffs accepted:**
- Blue-Green has INSTANT rollback (env flip); canary takes a few seconds (traffic shift)
- Blue-Green easier for DB schema migrations (Green tested isolated)

### Why Two PromQL Metrics (Not One)

**Two independent signals catch different failure modes:**

- **Success rate ≥ 95%** — Ensures good requests are healthy (catches generic degradation)
- **5xx rate ≤ 1%** — Ensures bad requests are minimal (catches specific server errors)

**Both must pass.** One could be high if the other isn't a problem (e.g., 90% success rate due to slow responses being timed-out by clients = NOT a 5xx spike).

### Why `failureLimit: 1` (Strict)

For portfolio scope, false-positive aborts are acceptable (just retry the deploy). False-negative promotes are NOT acceptable (broken code reaches 100%).

In production with noisier traffic, you'd bump to `failureLimit: 3` for noise tolerance.

### Why Manual Approval After Automated Analysis

**Two-layer defense:**
- **Automated catches DEFINITE failures** with objective thresholds
- **Human catches "this looks weird"** — slow memory growth, unusual latency distributions, patterns that don't trip thresholds but feel off

For portfolio scope, the manual gate is appropriate. For a mature pipeline with comprehensive metrics, you'd remove it — automation should EARN trust over time.

### Why `verify-infra-bootstrap` Gate

Don't deploy canary to a half-broken cluster. The gate queries GitHub's API for the latest infra-bootstrap conclusion and fails if it wasn't 'success'.

---

<a name="the-4-steps"></a>
## 4. The 4 Canary Steps Walkthrough

```yaml
strategy:
  canary:
    steps:
      - setWeight: 20                # STEP 1: 20% traffic to canary
      - pause: { duration: 2m }      # STEP 2: 2-min auto-resume pause
      - analysis: ...                # STEP 3: PromQL analysis
      - pause: {}                    # STEP 4: INDEFINITE manual pause
```

### Step 1: `setWeight: 20`
- ALB target group weights change: 80% stable / 20% canary
- New canary pods spin up (matching `maxSurge: 1`)
- Existing stable pods continue serving 80% of traffic
- Old stable pods are NEVER scaled down (important for fast rollback)

### Step 2: `pause: { duration: 2m }`
- Auto-resumes after 2 minutes
- Allows Prometheus to scrape 2+ minutes of canary metrics
- Prometheus default scrape interval is 15s → ~8 data points

### Step 3: `analysis`
- Runs AnalysisTemplate `api-gateway-prometheus-analysis`
- Two PromQL metrics, both `interval: 1m, count: 3, failureLimit: 1`
- Total analysis time: 3 minutes (1 min × 3 counts)
- One failed metric = abort entire rollout

### Step 4: `pause: {}`
- INDEFINITE pause — waits forever
- Rollout sits at 20% traffic until human acts
- Promote: `kubectl argo rollouts promote api-gateway` → 100%
- Abort: `kubectl argo rollouts abort api-gateway` → back to 100% stable

**Total time at 20% before promote**: 2 min pause + 3 min analysis = **5 minutes minimum.**

---

<a name="code-walkthrough"></a>
## 5. Code Walkthrough — 3 Files

### File 1: `kubernetes/api-gateway/deploy.yaml` (the Rollout)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout                                    # ← CRD, not Deployment
metadata:
  name: api-gateway
  namespace: petclinic
spec:
  replicas: 2
  revisionHistoryLimit: 3                        # ← Keep 3 revisions for rollback
  progressDeadlineSeconds: 600                   # ← 10 min for stalled rollout
  rollbackWindow:
    revisions: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: api-gateway
  strategy:
    canary:
      stableService: api-gateway-stable          # ← 3-service pattern
      canaryService: api-gateway-canary
      maxSurge: 1
      maxUnavailable: 0
      trafficRouting:
        alb:
          ingress: frontend-proxyr               # ← ALB integration via Ingress
          rootService: api-gateway
          servicePort: 8080
      steps:
        - setWeight: 20
        - pause: { duration: 2m }
        - analysis:
            templates:
              - templateName: api-gateway-prometheus-analysis
            args:
              - name: prometheus-address
                value: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
              - name: canary-service
                value: api-gateway-canary
        - pause: {}
  template:
    # ... pod spec (same as a Deployment) with security context, container, etc.
```

### File 2: `kubernetes/api-gateway/analysis-template.yaml` (the metrics)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: api-gateway-prometheus-analysis
  namespace: petclinic
spec:
  args:
    - name: prometheus-address
    - name: canary-service
  metrics:
    - name: canary-success-rate
      interval: 1m
      count: 3
      failureLimit: 1
      successCondition: result[0] >= 0.95
      provider:
        prometheus:
          address: "{{args.prometheus-address}}"
          query: |
            sum(rate(http_server_requests_seconds_count{service="{{args.canary-service}}",status!~"5.."}[2m]))
            /
            clamp_min(sum(rate(http_server_requests_seconds_count{service="{{args.canary-service}}"}[2m])), 0.001)

    - name: canary-5xx-rate
      interval: 1m
      count: 3
      failureLimit: 1
      successCondition: result[0] <= 0.01
      provider:
        prometheus:
          address: "{{args.prometheus-address}}"
          query: |
            sum(rate(http_server_requests_seconds_count{service="{{args.canary-service}}",status=~"5.."}[2m]))
            /
            clamp_min(sum(rate(http_server_requests_seconds_count{service="{{args.canary-service}}"}[2m])), 0.001)
```

### File 3: `.github/workflows/api-gateway-canary.yaml` (the workflow)

Structure:
- **Trigger** (lines 3-9): `workflow_dispatch` (manual) + `push: branches: [main]` + `paths: kubernetes/api-gateway/**`
- **Concurrency** (lines 10-12): `group: api-gateway-production` prevents parallel canary deploys
- **Job 1: verify-infra-bootstrap** (lines 22+): Queries GitHub API for last bootstrap conclusion; fails if not success
- **Job 2: deploy-canary** (lines 57+): On self-hosted runner; runs `kubectl apply -f kubernetes/api-gateway/`; waits for Rollout to reach manual pause

---

<a name="foundation-concepts"></a>
## 6. Foundation Concepts

(Detailed in [Vocabulary](#vocabulary). Key new concepts in Phase 5:)

- **Progressive delivery** — traffic phases instead of all-or-nothing
- **`kind: Rollout` vs `kind: Deployment`** — pluggable canary/blue-green strategies
- **3-service pattern** — root + stable + canary Services for traffic split
- **ALB trafficRouting** — Argo Rollouts integrates with AWS LBC for target group weight changes
- **AnalysisTemplate** — reusable PromQL gate definitions
- **`successCondition`** — PromQL expression that must evaluate true
- **`failureLimit`** — strict threshold for abort
- **`clamp_min`** — divide-by-zero defensive math
- **Two-layer defense** — automated metrics + human Grafana review
- **`pause: { duration: Xm }`** vs **`pause: {}`** — timed vs indefinite
- **AnalysisRun (instance) vs AnalysisTemplate (spec)** — debugging distinction

---

<a name="hostile-qa"></a>
## 7. 5 Hostile Q&A (Drilled — Summaries)

Full Q&As with ideal answers, secret weapons, follow-ups live in **[phase-5-qa.md](phase-5-qa.md)**.

| Q | Question | Score | Key insight |
|---|----------|-------|-------------|
| **Q1** | "Walk me through your canary deployment end to end" | **8.0** (R2) | Step order: 20% FIRST → 2m pause → analysis → manual pause. Not inverted. |
| **Q2** | "Why canary over blue-green for THIS project?" | **7.5** | Cost ($20 budget), blast radius (5x), automated analysis. Tradeoff: DB migrations + rollback speed. |
| **Q3** | "Walk me through your AnalysisTemplate. What queries, what thresholds?" | **7.0** | 2 PromQL metrics: `status!~"5.."` for success, `status=~"5.."` for 5xx. Thresholds 95% and 1%. `clamp_min` for divide-by-zero. |
| **Q4** | "What happens if canary analysis fails? Walk me through rollback" | **7.0** | Immediate ALB shift to 100% stable (seconds, not phases). Old stable pods never scaled down. `kubectl describe analysisrun` for diagnostics. |
| **Q5** | "Why manual approval gate? Isn't automated analysis enough?" | **8.0** | Two-layer defense: automated catches definite failures; humans catch 'this looks weird'. Trust through verification. |

**Phase 5 Final Average: 7.5/10.**

---

<a name="power-phrases"></a>
## 8. Power Phrases & Secret Weapons

### Canary Mechanics
- ✨ **"Progressive delivery — catch bad images at 20% blast radius, not 100%"**
- ✨ **"5x reduction in user impact"**
- ✨ **"Old stable pods were NEVER scaled down — rollback is 'stop sending traffic to canary'"**
- ✨ **"Few seconds, not phases — abort is intentionally fast"**
- ✨ **"In-flight requests drain naturally as ALB stops sending new traffic"**

### AnalysisTemplate
- ✨ **"`status!~"5.."` is the PromQL regex for non-5xx"**
- ✨ **"`clamp_min(..., 0.001)` prevents division by zero when no traffic exists yet"**
- ✨ **"`failureLimit: 1` is intentionally strict — production might bump to 3 for noise tolerance"**
- ✨ **"Args make the template reusable across services"**
- ✨ **"GOOD ≥ 95%, BAD ≤ 1%"** (threshold mnemonic)

### Tradeoffs vs Blue-Green
- ✨ **"Progressive exposure on the same node footprint"** (canary's cost win)
- ✨ **"Blue-Green doubles infrastructure during the deploy window"**
- ✨ **"DB schema migrations harder with canary — both versions share the same DB"**
- ✨ **"In regulated industries or for major DB migrations, I'd budget for Blue-Green"**

### Manual Approval Philosophy
- ✨ **"Automated catches DEFINITE failures; humans catch 'this looks weird'"**
- ✨ **"Trust through verification — automation should EARN trust over time"**
- ✨ **"Two-layer defense — different failure modes, both add value"**

### Diagnostic / Recovery
- ✨ **"`kubectl describe analysisrun` shows specific PromQL query results"**
- ✨ **"`kubectl argo rollouts get api-gateway -w` for live monitoring"**
- ✨ **"AnalysisRun is the instance; AnalysisTemplate is the spec"**

---

<a name="common-mistakes"></a>
## 9. Common Mistakes to Avoid

| Mistake | Why it hurts |
|---|---|
| Inverting step order ("if analysis passes, send 20%") | Wrong — 20% FIRST so analysis has data to measure |
| Mentioning intermediate "50%" step | Your spec doesn't have one. It's 20% → manual → 100%. |
| Saying "kubectl apply promotes" | Two different commands: `kubectl apply` deploys; `kubectl argo rollouts promote` advances past manual pause |
| Saying "5xx less than 0.01%" | The threshold is `≤ 0.01` (= **1%**, not 0.01%). Decimal, not percentage. |
| Saying "kubectl describe analysistemplate" | Correct is `kubectl describe analysisrun` (Run = instance, Template = spec) |
| Saying "phased rollback" | Abort = IMMEDIATE shift to 100% stable. No phases. |
| Saying "canary rollback takes 10 minutes" | `progressDeadlineSeconds` ≠ rollback time. Rollback takes seconds. |
| Forgetting old stable pods are running | They were never scaled down during canary. That's why rollback is fast. |
| Calling AnalysisTemplate "analysis-template" (kebab) | It's `AnalysisTemplate` (PascalCase) |
| Saying "Argo CD" when meaning "Argo Rollouts" | Two different products from the Argo project. CD is GitOps; Rollouts is progressive delivery. |

---

<a name="cheat-card"></a>
## 10. Cheat Card (One-Page Summary)

### Phase 5 Architecture
```
[PR merged to main]
       ↓
[CI committed image tag bump → push event on main]
       ↓
[api-gateway-canary.yaml triggered via on: push: branches: [main] + paths filter]
       ↓
┌────────────────────────────────────────┐
│  Job 1: verify-infra-bootstrap         │
│  ├── Query GitHub API for last        │
│  │   infra-bootstrap conclusion       │
│  └── Fail if not 'success'            │
└──────────────────┬─────────────────────┘
                   ↓
┌────────────────────────────────────────┐
│  Job 2: deploy-canary                  │
│  ├── kubectl apply -f api-gateway/    │
│  └── Wait for Rollout to reach pause  │
└──────────────────┬─────────────────────┘
                   ↓
┌────────────────────────────────────────┐
│  Argo Rollouts Controller executes:    │
│  ├── setWeight: 20    (ALB 80/20)     │
│  ├── pause: 2m         (data gather)  │
│  ├── analysis: ...     (PromQL × 2)   │
│  └── pause: {}         (MANUAL)       │
└──────────────────┬─────────────────────┘
                   ↓
            [Human in Grafana]
                   ↓
       PROMOTE             ABORT
       ↓                   ↓
   100% canary         100% stable
   (new stable)        (rolled back)
```

### The 4 Numbers to Remember
- **20%** — canary traffic weight
- **5 min** — total at 20% (2m pause + 3m analysis)
- **5x** — blast radius reduction (20% vs 100%)
- **failureLimit: 1** — strict abort threshold

### The 2 PromQL Queries
```promql
# Success rate (must be ≥ 0.95):
sum(rate(http_server_requests_seconds_count{service=X,status!~"5.."}[2m]))
/
clamp_min(sum(rate(http_server_requests_seconds_count{service=X}[2m])), 0.001)

# 5xx rate (must be ≤ 0.01):
sum(rate(http_server_requests_seconds_count{service=X,status=~"5.."}[2m]))
/
clamp_min(sum(rate(http_server_requests_seconds_count{service=X}[2m])), 0.001)
```

### The 4 Diagnostic Commands
```bash
kubectl argo rollouts get api-gateway        # Current state
kubectl argo rollouts get api-gateway -w     # Live watch
kubectl describe analysisrun -n petclinic    # PromQL query results
kubectl argo rollouts promote api-gateway    # Advance past manual pause
kubectl argo rollouts abort api-gateway      # Manual abort
```

### Score Targets
| Question Type | Target |
|---|---|
| Canary walkthrough | 8+ |
| Canary vs Blue-Green | 8+ |
| AnalysisTemplate PromQL | 8+ |
| Rollback flow | 8+ |
| Manual approval philosophy | 8+ |

### Universal Phase 5 Answer Framework
1. **State the canary concept** (progressive delivery)
2. **Name the mechanism** (Rollout CRD, 3-service pattern, ALB, AnalysisTemplate)
3. **Cite specific numbers** (20%, 5 min, 5x reduction)
4. **State the tradeoff** (vs blue-green or vs auto-promote)
5. **Senior closer** (when you'd evolve the pattern — more metrics, remove manual gate)

---

## Phase 5 — COMPLETE ✅

**Average score across 5 questions: 7.5/10 — interview-viable at $120-165K band.**

Next: **Phase 6 — RDS + Secrets Manager** (the database wiring + credential rotation story)
