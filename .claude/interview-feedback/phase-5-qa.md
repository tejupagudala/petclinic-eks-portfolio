# Phase 5 — Q&A Drilled Bank

**Phase 5 in progress. Q1 complete; Q2-Q5 pending.**

Companion to (future) `phase-5-reference.md`. This file = hostile Q&As, ideal answers, and follow-ups for the Argo Rollouts Canary deployment phase.

---

## Table of Contents

- [Q1: "Walk me through how your canary deployment works, end to end"](#q1-canary-walkthrough)
- Q2: "Why canary over blue-green for THIS project?" (pending)
- Q3: "Walk me through your AnalysisTemplate. What queries does it run, and why those thresholds?" (pending)
- Q4: "What happens if your canary analysis fails? Walk me through the rollback." (pending)
- Q5: "Why is there a manual approval gate after the analysis? Isn't automated analysis enough?" (pending)

---

<a name="q1-canary-walkthrough"></a>
## Q1: "Walk me through how your canary deployment works, end to end"

**Round 1 — 2026-06-03 — Score: 6.5/10**
**Round 2 — 2026-06-03 — Score: 8.0/10** 🔒

**R2 fixes Sai applied:**
- ✅ Corrected step order: 20% traffic FIRST → 2 min pause → analysis (not inverted)
- ✅ Removed made-up "50% then 100%" step (matches spec: 20% → manual → 100%)
- ✅ Separated `kubectl apply` (deploys) from `kubectl argo rollouts promote` (advances past manual pause)
- ✅ Added specific Grafana metrics to review (5xx in last 5 min, p95 latency, CPU, memory)
- ✅ Added 5x blast radius framing
- ✅ Mentioned `failureLimit: 1` as strict abort threshold

**R2 still missing for 9-10:**
- Inverted 5xx threshold direction (said `>= 0.01`; correct is `<= 0.01`)
- Command syntax: `kubectl argo rollouts promote api-gateway` (not "kubectl promote argo rollout")
- Didn't distinguish `pause: { duration: 2m }` (auto-resume) vs `pause: {}` (indefinite)
- Didn't mention `kubectl argo rollouts abort` option

**What Sai got right:**
- ✅ Strong WHY opening (progressive delivery, all-or-nothing previously)
- ✅ Full trigger chain (CI → manifest update → PR merge → canary workflow triggers)
- ✅ Paths filter mentioned
- ✅ verify-infra-bootstrap gate explained
- ✅ Both Prometheus metrics named (success rate, 5xx rate)
- ✅ 3-service pattern (root, stable, canary)
- ✅ ALB targetGroupRouting integration
- ✅ Manual approval pause + final state

**What to fix (the technical errors):**

❌ **ERROR 1: Inverted step ordering**
- Sai said: "if analysis passes, 20% traffic is sent"
- **Correct order:** `setWeight: 20` → `pause: 2m` → `analysis` → `pause: {}` (manual)
- **Why:** Need traffic FIRST to generate metrics for analysis

❌ **ERROR 2: Made-up "50% then 100%" step**
- Sai said: "after 20%, moves to 50% then 100%"
- **Spec reality:** Only `setWeight: 20` → manual approval → straight to 100%. No 50% step.

❌ **ERROR 3: Conflated kubectl apply with rollouts promote**
- Sai said: "kubectl apply -f kubernetes/api-gateway/ which promotes the argo rollout"
- **Correct:** `kubectl apply` DEPLOYS the spec; `kubectl argo rollouts promote api-gateway` ADVANCES past the manual approval pause

⚠️ **Minor:** Inverted analysis condition wording (95% boundary direction)

**Ideal answer (~100 seconds spoken):**

> *"Canary deployment is progressive delivery — instead of all-or-nothing rollouts, I catch bad images at 20% traffic before they reach 100% of users. Here's the flow end-to-end:*
>
> *First, CI runs on PR, builds the image, and the updatek8s job rewrites the image tag in `kubernetes/api-gateway/deploy.yaml`, committing back to the PR branch. When I merge the PR, that becomes a push event on main. My `api-gateway-canary.yaml` workflow's `on: push: branches: [main]` with paths filter on `kubernetes/api-gateway/**` matches and the workflow triggers.*
>
> *Job 1 is `verify-infra-bootstrap` — it queries GitHub's API for the latest infra-bootstrap run on main and fails if the conclusion isn't 'success'. Don't deploy to a broken platform.*
>
> *Job 2 is `deploy-canary` on the self-hosted runner. It runs `kubectl apply -f kubernetes/api-gateway/` which applies the Rollout spec. Argo Rollouts controller sees the spec change and begins executing the canary steps.*
>
> *The steps are: setWeight 20 first — ALB starts routing 20% of traffic to canary pods, 80% to stable, using the 3-service pattern with stable, canary, and root services. Then pause for 2 minutes so Prometheus has time to scrape canary metrics. Then analysis runs my AnalysisTemplate — two PromQL queries against Prometheus: success rate must be ≥ 95%, and 5xx rate must be ≤ 1%. The interval is 1 minute, count is 3, and failureLimit is 1 — meaning one failed check aborts the rollout. If aborted, ALB shifts 100% back to stable. If passes, the rollout pauses indefinitely for manual approval.*
>
> *I review canary metrics in Grafana, then run `kubectl argo rollouts promote api-gateway` — that advances past the manual pause and Argo Rollouts shifts traffic to 100% canary. Canary pods become the new stable, old stable pods are scaled down.*
>
> *Net effect: bad images caught at 20% blast radius instead of 100% — 5x reduction in user impact."*

**The Correct Step Order (memorize this):**
```
setWeight: 20          → ALB routes 20% traffic to canary
       ↓
pause: { duration: 2m } → Wait for Prometheus to gather data
       ↓
analysis: ...          → 2 PromQL queries, 3x over 3 min
       ↓
pause: {}              → Manual approval (indefinite)
       ↓
[human runs: kubectl argo rollouts promote api-gateway]
       ↓
100% canary            → Canary becomes new stable
```

**Secret weapon phrases:**
- *"Progressive delivery — catch bad images at 20% blast radius, not 100%"*
- *"5x reduction in user impact"*
- *"`failureLimit: 1` — one failed check aborts the rollout"*
- *"`kubectl argo rollouts promote api-gateway` advances past manual pause"*
- *"3-service pattern: stable, canary, root — ALB splits via targetGroupRouting"*

**Likely hostile follow-ups:**
- *"What if Prometheus is down during analysis?"* → AnalysisTemplate treats query failures as inconclusive; rollout pauses (doesn't auto-promote)
- *"Why 2 min pause before analysis?"* → Prometheus scrape interval default 15s; 2 min ensures enough data points for meaningful average
- *"How do you abort manually?"* → `kubectl argo rollouts abort api-gateway`
- *"How do you watch progress live?"* → `kubectl argo rollouts get api-gateway -w`
- *"What if you want different traffic weights (e.g., 10/30/60/100)?"* → Add more `setWeight` + `pause` + `analysis` steps in the Rollout spec

---

## Q2: "Why canary over blue-green for THIS project? What's the tradeoff?"

**Round 1 — 2026-06-03 — Score: 7.5/10**

**What Sai got right:**
- ✅ Explained blue-green correctly BEFORE choosing canary (senior signal)
- ✅ Cost argument with specifics ("$20/month budget")
- ✅ Blast radius framing ("20% traffic, thoroughly tested")
- ✅ Honestly acknowledged the tradeoff (canary slower rollback)
- ✅ Context-aware closing ("time-sensitive companies would go blue-green")

**What costs the 2.5 points:**
- ❌ **MAJOR factual error:** Said canary rollback takes "600 seconds = 10 min" — that's `progressDeadlineSeconds` (stalled-deploy timeout), NOT rollback time. Actual canary rollback via `kubectl argo rollouts abort` is a few seconds (ALB target group weight change)
- ❌ Missed "5x blast radius reduction" specific number
- ❌ Missed the DB migration tradeoff (huge senior insight)
- ❌ Didn't use "progressive exposure on the same node footprint" senior phrase

**Ideal answer (~75 seconds spoken):**

> *"I evaluated both. Blue-Green = two parallel production environments — Blue is stable, Green has the new version. You promote Green by flipping traffic; rollback is instant by flipping back. Canary = one environment, gradually shift traffic from old to new — 20% first, analysis, then 100%.*
>
> *I chose canary for three reasons.*
>
> *First, cost. Blue-Green doubles infrastructure during the deploy window — two full EKS nodegroups, potentially two RDS instances. My budget is $20/month — that math doesn't work. Canary gives progressive exposure on the SAME node footprint — new pods alongside old, ALB splits traffic via TargetGroupBindings.*
>
> *Second, blast radius. Canary catches issues at 20% traffic — 5x reduction in potential user impact compared to Blue-Green's all-or-nothing cutover.*
>
> *Third, automated analysis fits naturally — Prometheus AnalysisTemplate at 20% gives objective abort/promote signals that Blue-Green's all-at-once switch doesn't enable.*
>
> *The tradeoffs I accepted: Blue-Green has INSTANT rollback — flip the switch back to Blue. Canary takes a few seconds to shift ALB traffic weights back to 100% stable. And Blue-Green is easier for DB schema migrations because Green can be tested in isolation with its own DB state — Canary has both versions sharing the same DB, which is harder when schemas break.*
>
> *In a different context — time-sensitive financial services, healthcare, or major DB migrations — I'd budget for Blue-Green. For my portfolio's stateless API services at $20/month, Canary is the right call. Deliberate choice, not a constraint."*

### Comparison Matrix (memorize this)

| | Canary | Blue-Green |
|---|---|---|
| **Infra cost** | Same node footprint | DOUBLES during deploy |
| **Rollout** | Gradual (20% → 100%) | Instant switch |
| **Rollback** | Few seconds (ALB shift) | Instant (env flip) |
| **Risk detection** | At 20% — 5x blast radius reduction | All-or-nothing |
| **DB migrations** | Hard (both versions share DB) | Easy (Green tested isolated) |
| **Best for** | Stateless services, tight budget | Major DB migrations, time-sensitive |

### Follow-up: "How does the DB migration story actually work?"

This is a likely follow-up because Q2 raises it. Here's the depth:

**The core problem:** Canary keeps OLD and NEW versions running simultaneously against the SAME database. If schema changes between versions, there's no good time to migrate.

**Three schema change scenarios:**

| Operation | Canary | Blue-Green |
|---|---|---|
| **Add column** | ✅ Safe (backward-compatible) | ✅ Safe |
| **Rename column** | ❌ BREAKS — need 3-4 deploys (expand/contract) | ✅ Atomic, easy |
| **Drop column** | ❌ BREAKS — need 3-4 deploys (expand/contract) | ✅ Atomic, easy |

**The expand/contract pattern (canary's workaround):**
```
DEPLOY 1: Add new column, keep old (both versions work)
DEPLOY 2: App writes to BOTH old and new columns
DEPLOY 3: Backfill old data to new column
DEPLOY 4: Drop old column AFTER old version is 100% gone
```

**4 deploys, weeks of coordination, every deploy must be backward-compatible.**

**Blue-Green sidesteps:** Stand up Green with NEW schema + NEW app version, test in isolation, switch traffic atomically. ONE deploy.

**How this applies to YOUR project:**
- Your canary is on `api-gateway` (stateless — no DB queries) → DB problem doesn't bite
- If you extended canary to `customers-service` or `vets-service` (DB-touching) → breaking schema changes would force expand/contract or Blue-Green

**Interview one-liner for the follow-up:**

> *"Canary keeps old and new versions running simultaneously against the same DB, so any schema change must be backward-compatible — adding columns works, renaming or dropping requires a 3-4 deploy expand/contract pattern. Blue-Green sidesteps this because old and new never run simultaneously; you migrate atomically during cutover. My canary is on api-gateway which is stateless, so the schema problem doesn't bite me — but if I extended canary to DB-touching services, breaking changes would force expand/contract or Blue-Green for that service."*

### Secret weapon phrases for Q2

- *"Progressive exposure on the same node footprint"* (canary's cost advantage)
- *"5x reduction in blast radius — 20% vs 100% user impact"*
- *"Different context — time-sensitive financial services, healthcare, major DB migrations — I'd budget for Blue-Green"*
- *"My canary is on api-gateway which is stateless — DB schema problem doesn't bite me"*
- *"Expand/contract pattern — 4 deploys for one breaking schema change"*

### Other likely follow-ups for Q2

- *"What if you had to do canary on a DB-touching service?"* → Expand/contract pattern; or Blue-Green for that one service while canary stays elsewhere
- *"What if Blue-Green's instant rollback is required (e.g., regulated industry)?"* → Budget for it; cost goes from $20/mo to ~$40-50/mo during deploy windows
- *"How would you decide between canary and Blue-Green for a NEW service?"* → Stateless + tight budget = canary. DB-coupled + breaking changes likely = Blue-Green. High-traffic + strict SLA = Blue-Green for instant rollback.
- *"Why not feature flags instead of canary?"* → Feature flags are application-level (need code support); canary is infrastructure-level (works for any app). Both can coexist — canary for infra changes, feature flags for user-targeted rollouts.

---

## Q3: "Walk me through your AnalysisTemplate. What queries does it run, and why those thresholds?"

**Round 1 — 2026-06-03 — Score: 7.0/10**

**What Sai got right:**
- ✅ Chronological context (canary workflow → analysis template)
- ✅ Both queries identified (success rate + 5xx rate)
- ✅ Timing math exact: 5 min total = 2 min pause + (1m interval × 3 counts)
- ✅ `failureLimit: 1` with "strict for safety" reasoning
- ✅ `clamp_min` for divide-by-zero protection explained
- ✅ SLA reasoning for 95% threshold

**What costs the 3 points:**
- ❌ **MAJOR threshold error:** Said "5xx less than 0.01%" — actual is `≤ 0.01` (= **1%**, not 0.01%). Off by 100x.
- ❌ Described queries conceptually but never said the actual PromQL
- ❌ Didn't mention the `status!~"5.."` regex syntax (PromQL regex for "NOT matching 5xx")
- ❌ Didn't mention `args` pattern (template reuse across services)
- ❌ Didn't mention Prometheus in-cluster service address

**Ideal answer (~90 seconds spoken):**

> *"My AnalysisTemplate lives at `kubernetes/api-gateway/analysis-template.yaml` — `kind: AnalysisTemplate`, an Argo Rollouts CRD. It takes two args — `prometheus-address` and `canary-service` — which makes it reusable for any service.*
>
> *Two metrics, both Prometheus-backed.*
>
> *Metric 1 — `canary-success-rate`. PromQL: `sum(rate(http_server_requests_seconds_count{service="api-gateway-canary",status!~"5.."}[2m]))` divided by `clamp_min(sum(rate(... total ...)), 0.001)`. The `status!~"5.."` is a PromQL regex for 'status NOT matching 5xx pattern' — so non-5xx (good) requests divided by total. Success condition: `result[0] >= 0.95` — must be at least 95% success rate.*
>
> *Metric 2 — `canary-5xx-rate`. Same shape but `status=~"5.."` in numerator — so 5xx (bad) requests divided by total. Success condition: `result[0] <= 0.01` — must be at most 1% 5xx errors.*
>
> *The `clamp_min(..., 0.001)` prevents division by zero when no traffic has hit the canary yet — returns a minimum denominator of 0.001 so the query doesn't blow up.*
>
> *Both metrics run with `interval: 1m, count: 3, failureLimit: 1` — query Prometheus every minute, 3 times total, abort if any single check fails. Combined with the 2-minute pre-analysis pause, total time at 20% traffic before manual approval is 5 minutes.*
>
> *Prometheus is reached via the in-cluster DNS: `http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090` — no external network hops.*
>
> *Why these thresholds: 95% success is standard SLA floor for HTTP services. 1% 5xx is industry-typical for healthy services. `failureLimit: 1` is intentionally strict — for a portfolio project I prioritize safety; in production with noisier traffic I might bump to `failureLimit: 3` for noise tolerance."*

### 🧠 Memory Tips for Q3

**Mnemonic for the two thresholds:**
> *"GOOD ≥ 95%, BAD ≤ 1%"*

Both expressed as decimals (0.95 and 0.01), not percentages.

**The 5-minute math:**
- 2-minute pause (pre-analysis)
- 1-minute interval × 3 counts = 3 minutes analysis
- Total: **2 + 3 = 5 minutes** at 20% traffic before manual approval

**The PromQL regex trick:**
- `status!~"5.."` = "NOT matching 5-anything" = **non-5xx (good)**
- `status=~"5.."` = "IS matching 5-anything" = **5xx (bad)**
- `..` is regex for "any 2 characters" — covers 500, 502, 503, 504, etc.

**The 4 key numbers to memorize:**
| Setting | Value | Why |
|---|---|---|
| Success threshold | ≥ 0.95 (= 95%) | Standard SLA floor |
| 5xx threshold | ≤ 0.01 (= 1%) | Industry-typical for healthy |
| `failureLimit` | 1 | Strict safety for portfolio |
| Total analysis time | 5 minutes | 2m pause + 3m queries |

**The `clamp_min` trick (one sentence):**
> *"Prevents division-by-zero when no canary traffic has flowed yet — returns 0.001 as minimum denominator."*

**The `args` pattern (one sentence):**
> *"Args make the template reusable — pass different `canary-service` arg and the same template works for vets-service-canary, customers-service-canary, etc."*

### Secret weapon phrases for Q3

- *"`status!~"5.."` is the PromQL regex for non-5xx"*
- *"`clamp_min(..., 0.001)` prevents division by zero when no traffic exists yet"*
- *"`failureLimit: 1` is intentionally strict — production with noisier traffic might bump to 3 for noise tolerance"*
- *"Args make the template reusable across services"*
- *"In-cluster Prometheus DNS — no external network hops"*

### Likely hostile follow-ups for Q3

- *"What if you wanted to add latency p95 as a metric?"* → Add a third metric block with PromQL `histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket[2m])) by (le))` and threshold like `<= 0.5` (500ms)
- *"Why `[2m]` rate window and not `[1m]`?"* → 2 min matches the pre-analysis pause window; gives more stable rate calculation, less noise
- *"What if Prometheus is unreachable during analysis?"* → AnalysisRun marks the metric as `Inconclusive`. Rollout pauses (doesn't auto-promote OR auto-abort)
- *"How do you debug a failed AnalysisRun?"* → `kubectl describe analysisrun -n petclinic` shows query results, failure reasons, all metric attempts
- *"Could you use Datadog/CloudWatch as the metric source instead?"* → Yes, Argo Rollouts supports multiple providers: `prometheus`, `datadog`, `cloudwatch`, `newrelic`, `wavefront`, `web` (custom HTTP), `kayenta`
- *"What's a `successCondition` vs `failureCondition`?"* → `successCondition` defines PASS; if missing, the inverse fails. `failureCondition` defines abort criteria explicitly. You can use either or both.

---

## Q4: "What happens if your canary analysis fails? Walk me through the rollback."

**Round 1 — 2026-06-03 — Score: 7.0/10**

**What Sai got right:**
- ✅ Abort trigger: `failureLimit: 1` hit → auto-abort
- ✅ Rollout status changes to `Degraded`
- ✅ revisionHistoryLimit awareness
- ✅ Both abort paths distinguished (auto + manual `kubectl argo rollouts abort`)
- ✅ GitHub workflow shows failure
- ✅ Diagnostic commands (`kubectl argo rollouts get`)
- ✅ Recovery flow chronologically correct

**What costs the 3 points:**
- ❌ **MAJOR factual error:** Said "phased rollback (20% → 50% → 100%)" — actual is **IMMEDIATE shift to 100% stable**. No phased rollback. Takes seconds.
- ⚠️ Terminology: Said "describe analysistemplate" — correct is **`kubectl describe analysisrun`** (Run is the instance; Template is the spec)
- ❌ Missed senior phrase: "Old stable pods NEVER scaled down — rollback is just 'stop sending traffic to canary'"
- ❌ Missed: in-flight requests drain naturally

**Ideal answer (~90 seconds spoken):**

> *"If my AnalysisTemplate hits `failureLimit: 1` — any single metric check fails — Argo Rollouts auto-aborts.*
>
> *Here's what happens automatically. The Rollout's status changes to `Degraded`. The ALB Controller updates the TargetGroup weights via the AWS API — canary weight goes from 20% to 0, stable weight goes from 80% to 100%. The shift takes a few seconds, not phases — abort is intentionally fast.*
>
> *Critical detail: the old stable pods were NEVER scaled down during canary. They were running the whole time at 80% traffic. So 'rollback' is just 'stop sending new traffic to canary pods' — no pod restart, no cold-start latency. In-flight requests on canary pods drain naturally as the ALB stops sending new traffic. Canary pods are then scaled down based on `revisionHistoryLimit: 3` — Argo Rollouts keeps the 3 most recent revisions for fast manual rollback to any of them.*
>
> *I can also abort manually via `kubectl argo rollouts abort api-gateway` — same effect as auto-abort.*
>
> *The GitHub Actions `deploy-canary` job reports failure when the Rollout enters Degraded state — the workflow step fails red, the PR check is red, and the diagnostic dumps run.*
>
> *To diagnose: `kubectl argo rollouts get api-gateway` shows abort reason and current step. `kubectl describe analysisrun -n petclinic` (the actual run, not the template) shows the specific PromQL query results — which metric failed, which value triggered the abort.*
>
> *Recovery path: fix the issue in code, push to PR — CI runs again, builds new image, updatek8s commits the new tag. Merge the PR to main — that triggers the canary workflow again with the FIXED image. New rollout starts from 20%, analysis runs against the fixed code, hopefully passes this time, manual approval, promoted to 100%."*

### Memory Tips for Q4

**The 5-second rollback math:**
- ALB target group weight change → seconds
- Old stable pods already running (not scaled down) → no cold start
- In-flight canary requests → drain naturally
- **Net rollback time: a few seconds**

**Template vs Run (memorize this):**
| Resource | What it is |
|---|---|
| `AnalysisTemplate` | The SPEC (your `analysis-template.yaml`) |
| `AnalysisRun` | An INSTANCE of running the template (one per rollout attempt) |

**To debug a specific failed analysis: `kubectl describe analysisrun -n petclinic`** (not analysistemplate)

**The 4 diagnostic commands:**
```bash
kubectl argo rollouts get api-gateway              # current state + abort reason
kubectl argo rollouts get api-gateway -w           # WATCH live
kubectl describe analysisrun -n petclinic          # PromQL query results
kubectl argo rollouts abort api-gateway            # manual abort
```

### Secret weapon phrases for Q4

- *"Old stable pods were NEVER scaled down — rollback is 'stop sending traffic to canary'"*
- *"Few seconds, not phases — abort is intentionally fast"*
- *"In-flight requests drain naturally as ALB stops sending new traffic"*
- *"`revisionHistoryLimit: 3` keeps 3 revisions for fast manual rollback"*
- *"`kubectl describe analysisrun` shows specific PromQL query results"*

### Likely hostile follow-ups for Q4

- *"What if the abort itself fails?"* → Argo Rollouts controller retries with exponential backoff; manual ALB target group weight change as last resort via AWS console
- *"How do you roll back to a version that's NOT the immediate previous?"* → `kubectl argo rollouts undo api-gateway --to-revision=N` (uses revisionHistoryLimit)
- *"What's the time between abort trigger and traffic being 100% stable?"* → Typically 5-15 seconds. ALB target group health check + weight update.
- *"Can the abort fail and leave traffic split?"* → Very rare. If it happens, manual intervention via AWS console (edit target group weights directly) or `kubectl patch rollout` to force status
- *"How would you make rollback automated based on user complaints?"* → Argo Rollouts supports webhooks/external metrics — could integrate with PagerDuty or a custom service that triggers abort on alert

---

## Q5: "Why is there a manual approval gate after the analysis? Isn't automated analysis enough?"

**Round 1 — 2026-06-03 — Score: 8.0/10** 🔒

**What Sai got right:**
- ✅ Two-layer defense framing
- ✅ Specific examples of what auto misses ("unusual patterns, weird latency distributions")
- ✅ Production context (customer impact, financial losses)
- ✅ Risk-aware framing ("extra safety net")
- ✅ Blast radius mention
- ✅ Clear tradeoff: speed vs safety

**What costs the 2 points:**
- ⚠️ Slight framing slip: said "if auto-abort failed" — actually the gate buffers the "false negative" risk where auto-PROMOTE happens on borderline metrics that should have been flagged
- ❌ Missed killer phrase: "Automated catches DEFINITE failures; humans catch 'this looks weird'"
- ❌ Missed: "When you'd REMOVE the gate" (progressive maturity)
- ❌ Missed: Industries where this is standard (banking, healthcare, fintech)

**Ideal answer (~75 seconds spoken):**

> *"Two-layer defense — automated and manual catch DIFFERENT failure modes.*
>
> *Automated AnalysisTemplate catches DEFINITE failures with objective thresholds — success rate below 95%, 5xx above 1%. Strict, numeric, fast.*
>
> *Humans catch 'this looks weird' — subjective signals that don't trip the automated thresholds but feel off. Slow memory growth that's still under the limit. Latency distribution shifting from p50 to p99 even though p95 is fine. CPU spikes that correlate with specific endpoints. Unusual patterns. These are things a human looking at Grafana spots in 30 seconds but no PromQL threshold catches.*
>
> *The tradeoff: rollout waits indefinitely at 20% for human availability. Could be hours. Slower than auto-promote. But for production traffic affecting customers, the safety net is worth the latency — small issues can cause significant financial or reputation damage.*
>
> *This two-layer pattern is standard in banking, healthcare, fintech — any industry where a bad deploy has compliance or financial consequences.*
>
> *For a portfolio with limited historical data and 3 PromQL metrics, the manual gate is the right call. As the pipeline matures — more metrics, months of baseline data, fewer false positives — I'd progressively remove the gate. Automation should EARN trust over time, not be granted it by default.*
>
> *The principle: trust through verification. Build automated detection, validate it produces the same conclusions a human would, then gradually remove the human."*

### Secret weapon phrases for Q5

- *"Automated catches DEFINITE failures; humans catch 'this looks weird'"*
- *"Trust through verification — automation should EARN trust over time"*
- *"Standard in banking, healthcare, fintech"*
- *"Progressive maturity — manual gate is scaffolding, not a permanent fixture"*
- *"Speed vs safety — picked safety for production-impacting deploys"*

### Likely hostile follow-ups for Q5

- *"What if no one's available to approve?"* → Rollout sits at 20% indefinitely. Could add an alerting webhook on `pause: {}` state to PagerDuty. For lower-stakes services, configure auto-promote after N hours.
- *"Doesn't this slow down deploys?"* → Yes — that's the tradeoff. For services where deploy speed > safety (e.g., experimental features), I'd remove the gate. For core API services, the safety wins.
- *"Could you replace the human with more sophisticated automation?"* → Yes — add more PromQL metrics (latency p95/p99, memory growth rate, error correlation across endpoints), use Datadog/Wavefront analyzers, or train a custom model. As coverage improves, remove the manual gate.
- *"What's the longest you've left a rollout paused at 20%?"* → Honest answer: hours during weekends. For production with real users, would need PagerDuty integration.

---

## Phase 5 — COMPLETE ✅

**Phase 5 Final Average: 7.5/10 across 5 questions.**

Pattern observation: Phase 5 questions are heavier on specific syntax/behavior (PromQL, abort mechanics, threshold precision) than Phase 4. Scores reflect the steeper technical bar.

---

---

## 📚 Phase 5 — Follow-up Answer Bank

Full ideal answers (not one-liners) for every hostile follow-up across Q1-Q5. Read these AFTER nailing the main Q.

---

### Q1 Follow-ups (Canary walkthrough)

**Q1.F1: "What if Prometheus is down during analysis?"**
> *"AnalysisTemplate treats Prometheus query failures as `Inconclusive` — not a pass and not a fail. The rollout pauses at the current step waiting for clarity. It does NOT auto-promote (safe-by-default) and does NOT auto-abort (don't want to abort on a transient Prometheus blip). I'd see the inconclusive status via `kubectl describe analysisrun`, investigate Prometheus health, and either manually abort if Prom is broken or wait for it to recover and re-trigger the metric query. The conservative default — pause when uncertain — is what you want for safety-critical rollouts."*

**Q1.F2: "Why 2 min pause before analysis?"**
> *"Prometheus default scrape interval is 15 seconds — so over 2 minutes I get about 8 data points per metric. With a `[2m]` rate window in my PromQL, that's enough samples to compute a meaningful per-second rate without noise. If I dropped to a 30-second pause, I'd have 2 data points and my rate calculation would be too noisy to trust. The 2-minute pause matches the rate window — they're paired numbers, not arbitrary."*

**Q1.F3: "How do you abort manually?"**
> *"`kubectl argo rollouts abort api-gateway` — same effect as auto-abort. ALB target group weights shift back to 100% stable in seconds. Rollout status goes to `Degraded`. I'd run this if I'm watching Grafana during the manual pause and spot a problem the automated analysis missed — say a slow memory leak or unusual latency distribution. Manual abort is the escape hatch the two-layer defense relies on."*

**Q1.F4: "How do you watch progress live?"**
> *"`kubectl argo rollouts get api-gateway -w` — the `-w` is the watch flag. It refreshes the rollout status in place, showing the current step, traffic weights, pod counts for stable and canary, and any abort reason if it fails. I'd run it in a split terminal alongside Grafana during the manual pause window so I can correlate metrics with the rollout state."*

**Q1.F5: "What if you want different traffic weights (e.g., 10/30/60/100)?"**
> *"Add more setWeight + pause + analysis blocks to the `steps` array in the Rollout spec. So: `setWeight: 10` → pause → analysis → `setWeight: 30` → pause → analysis → `setWeight: 60` → pause → analysis → manual pause → 100%. Each weight tier gets its own validation gate. The tradeoff is total deploy time — 4 weight tiers × 5 min each = 20 min minimum. For my portfolio I picked one weight (20%) for fast feedback; for production with strict SLAs I'd add intermediate tiers."*

---

### Q2 Follow-ups (Canary vs Blue-Green)

**Q2.F1: "What if you had to do canary on a DB-touching service?"**
> *"Two options. First, expand/contract pattern — 4 deploys for a breaking schema change: add new column → write to both → backfill → drop old. Old and new app versions stay compatible throughout. Slow (weeks of coordination) but works with canary. Second, mixed strategy — keep canary for stateless services like api-gateway, switch to blue-green ONLY for the DB-touching service during schema-breaking deploys. Different services can use different strategies; not a cluster-wide decision. For my project, api-gateway is stateless so the question doesn't bite; if I extended canary to customers-service for a schema migration, I'd use expand/contract."*

**Q2.F2: "What if Blue-Green's instant rollback is required (e.g., regulated industry)?"**
> *"Budget for it. Cost goes from ~$20/month to ~$40-50/month during deploy windows because you're running two parallel production environments. For regulated industries — banking, healthcare, fintech — the instant-rollback SLA is a hard compliance requirement, not a nice-to-have. The math works because the cost of a bad deploy (regulatory fine, customer harm, reputational damage) dwarfs the doubled infra cost. I'd also add automated traffic flip via Route53 weighted records or ALB listener rules so the cutover is one command, not a manual ops sequence."*

**Q2.F3: "How would you decide between canary and Blue-Green for a NEW service?"**
> *"Three-question decision tree. First — is it stateless? If yes, canary is viable; if it's DB-coupled with frequent schema changes, lean blue-green. Second — what's the budget? Tight budget = canary (single footprint); flexible = either. Third — what's the rollback SLA? Sub-second rollback required = blue-green (env flip); few-seconds acceptable = canary works. For most stateless microservices on a constrained budget, canary wins. For stateful or compliance-driven services with strict SLAs, blue-green wins."*

**Q2.F4: "Why not feature flags instead of canary?"**
> *"They solve different problems and work together. Canary is infrastructure-level — routes traffic between two versions of the same deployment artifact. Feature flags are application-level — code-gated branches inside ONE version that toggle on per-user or per-percentage. Canary tests 'is this build healthy under real traffic?'. Feature flags test 'does this feature work for these users?'. In a mature pipeline you'd use both: canary catches deployment-level regressions; feature flags do user-segmented rollouts inside the new version. They're complementary, not substitutes."*

---

### Q3 Follow-ups (AnalysisTemplate)

**Q3.F1: "What if you wanted to add latency p95 as a metric?"**
> *"Add a third metric block in the AnalysisTemplate. PromQL would be `histogram_quantile(0.95, sum(rate(http_server_requests_seconds_bucket{service="api-gateway-canary"}[2m])) by (le))`. The `le` label is the histogram bucket boundary — Spring Boot Micrometer exports histogram buckets automatically. Threshold something like `successCondition: result[0] <= 0.5` for sub-500ms p95. Same interval/count/failureLimit pattern as the other metrics. Adding p95 catches latency degradation that success-rate metrics miss — a slow deploy can still return 200s while crawling."*

**Q3.F2: "Why `[2m]` rate window and not `[1m]`?"**
> *"Two reasons. First, it matches the 2-minute pre-analysis pause — by the time analysis runs, there's a full 2-minute window of canary data to compute the rate from. Second, longer rate windows smooth out noise — a 1m window can spike or dip on individual scrape blips. 2m gives a more stable rate average. Tradeoff is reactivity: a sudden 5xx spike at minute 1 isn't fully reflected until minute 2. For my use case, stability matters more than instant reaction since I have a 5-minute total analysis window anyway."*

**Q3.F3: "What if Prometheus is unreachable during analysis?"**
> *"AnalysisRun marks the metric as `Inconclusive`. The rollout pauses — doesn't auto-promote OR auto-abort. Safe default for ambiguity. I'd diagnose via `kubectl describe analysisrun -n petclinic` which shows the actual provider error (DNS resolution failure, connection timeout, etc.), check Prometheus pod health in monitoring namespace, and either manually abort if Prom is broken or wait. Could add a separate liveness metric in the AnalysisTemplate to detect Prom unavailability explicitly and fail-fast."*

**Q3.F4: "How do you debug a failed AnalysisRun?"**
> *"`kubectl describe analysisrun -n petclinic` is the first stop — shows every metric attempt, the PromQL query that was actually sent, the result value, and which condition failed. If the query returned no data, I check the canary service's pod metrics endpoint: `kubectl port-forward pod/api-gateway-canary-... 9090:8080` then curl `/actuator/prometheus` to verify Micrometer is exporting. If the query returned data but wrong values, I'd run the same PromQL directly in Prometheus UI to see if the threshold logic is wrong vs the canary code is genuinely broken."*

**Q3.F5: "Could you use Datadog or CloudWatch instead of Prometheus?"**
> *"Yes. Argo Rollouts supports multiple metric providers: `prometheus`, `datadog`, `cloudwatch`, `newrelic`, `wavefront`, `web` (any HTTP endpoint returning JSON), and `kayenta` (Spinnaker's analyzer). The AnalysisTemplate just swaps the `provider` block — keep the same metrics structure, swap PromQL for Datadog query syntax or CloudWatch metric name + statistic. I'd pick based on what the org already has — if Datadog is the existing observability stack, use Datadog. My project uses Prometheus because kube-prometheus-stack is already deployed and the integration is the most mature."*

**Q3.F6: "What's a successCondition vs failureCondition?"**
> *"`successCondition` defines PASS — the rollout continues if the expression evaluates true. `failureCondition` defines ABORT explicitly — the rollout aborts if it evaluates true. If only successCondition is defined, anything else fails. If only failureCondition is defined, anything else passes. You can use both for tristate logic — success OR failure OR inconclusive. My template uses just successCondition because the inverse (fail) is the desired behavior when the success threshold isn't met."*

---

### Q4 Follow-ups (Rollback flow)

**Q4.F1: "What if the abort itself fails?"**
> *"Argo Rollouts controller retries the abort with exponential backoff — it keeps re-attempting the TargetGroup weight update via the AWS Load Balancer Controller. If retries exhaust, the rollout stays in `Degraded` status with the abort attempt logged. Last-resort manual intervention: edit the ALB target group weights directly via AWS console or CLI to set canary to 0 and stable to 100. Then `kubectl patch rollout api-gateway --type=merge -p '{\"status\":{\"abort\":true}}'` to force the rollout status. Very rare scenario — would indicate AWS API issues or controller misconfiguration."*

**Q4.F2: "How do you roll back to a version that's NOT the immediate previous?"**
> *"`kubectl argo rollouts undo api-gateway --to-revision=N` where N is the revision number. Argo Rollouts keeps the last 3 revisions (`revisionHistoryLimit: 3` in my spec) so I can roll back up to 3 versions back. List revisions with `kubectl argo rollouts history api-gateway`. Each revision has its image tag and config, so undo creates a new rollout that goes through the same canary process (20% → analysis → manual approval) but using the older spec. Not instant — still goes through the full canary cycle for safety."*

**Q4.F3: "What's the time between abort trigger and traffic being 100% stable?"**
> *"Typically 5-15 seconds. Breakdown: AWS LBC sees the rollout status change in 1-2 seconds (controller reconcile loop), API call to ALB to update TargetGroup weights takes 1-3 seconds, ALB propagates the new weights to all its targets in 2-5 seconds, in-flight requests on canary pods drain over the next few seconds. Old stable pods were already healthy and serving traffic at 80%, so the shift from 80→100 is instant on their side — no warm-up. Total user-visible impact: maybe 5-15 seconds of slightly elevated 5xx if the canary was actively serving error responses."*

**Q4.F4: "Can the abort fail and leave traffic split?"**
> *"Very rare. The most common cause would be AWS API throttling or LBC controller crash mid-update. If it happens, the symptom is: rollout status shows `Degraded` but ALB target group still has canary weight > 0. Detection: `kubectl describe rollout api-gateway` shows the abort attempt, `aws elbv2 describe-target-group-attributes` shows the actual weight. Recovery: manual ALB weight update via console, then `kubectl patch` to align rollout status. I'd treat this as a P0 incident and post-mortem the LBC + AWS API health."*

**Q4.F5: "How would you make rollback automated based on user complaints?"**
> *"Argo Rollouts supports webhook providers and `web` metric provider — I'd plumb in external signals. Architecture: PagerDuty webhook fires on a customer-impact alert → Lambda function calls `kubectl argo rollouts abort` via EKS API. Or use the `web` provider in AnalysisTemplate to poll an alert aggregation service (Sentry, Datadog) for new high-priority issues correlated with the deploy, and fail the analysis if any are open. This shifts the loop from 'engineer sees alert and clicks abort' to 'alert system triggers abort directly'. Worth the engineering investment for production with millions of users; overkill for my portfolio."*

---

### Q5 Follow-ups (Manual approval gate)

**Q5.F1: "What if no one's available to approve?"**
> *"Rollout sits at 20% indefinitely — the `pause: {}` is genuinely infinite. For my portfolio, that's acceptable because canary deploys are infrequent and intentional. For production, I'd add a PagerDuty webhook fired on `pause: {}` state via a small controller watching Rollout status — pages whoever's on-call. For lower-stakes services where blocking is worse than auto-promoting, configure `pause: { duration: 2h }` instead of `{}` so it auto-resumes after a timeout. The right answer depends on which failure mode is worse: 'unnoticed bad deploy at 100%' or 'rollout stuck at 20% indefinitely'."*

**Q5.F2: "Doesn't this slow down deploys?"**
> *"Yes — that's the explicit tradeoff. 5-minute automated analysis + manual review window vs maybe 30 seconds for an auto-promote. For services where deploy speed matters more than safety — experimental features, internal tools, A/B test variants — I'd remove the gate. For core API services touching customer traffic, the safety wins. Mature orgs tier this: experimental services auto-promote, core services require manual approval, regulated services require multi-person approval. My choice for api-gateway reflects 'this is the entry point — slow down here is worth it.'"*

**Q5.F3: "Could you replace the human with more sophisticated automation?"**
> *"Yes — and that's the maturity path. Add more PromQL metrics: latency p95/p99, memory growth rate, error correlation across endpoints, request distribution shifts. Integrate Datadog or Wavefront analyzers for anomaly detection beyond static thresholds. Train a custom model on historical deploy outcomes to flag 'this canary looks like the bad ones we aborted before.' As coverage and confidence improve, progressively remove the manual gate. Principle: automation must EARN trust by being validated against human judgment over many deploys, then graduate to autonomous."*

**Q5.F4: "What's the longest you've left a rollout paused at 20%?"**
> *"Honest answer — for my portfolio, hours during weekends when I'm not at the keyboard. That's fine because there are no real users. For production with real customer traffic, that would be a problem — 20% traffic to potentially-buggy pods is real customer impact, just smaller. The fix is PagerDuty integration on the pause state and an SLA on response time. For my project, the long pause exposed the gap: 'manual gate' assumes a human is reasonably available, which I am not for a portfolio. In a production design I'd build the on-call hookup before relying on manual gates."*

---

## Phase 5 — Trajectory (in progress)

| Question | R1 | R2 |
|---|---|---|
| Q1 — Canary walkthrough | 6.5/10 | **8.0/10** 🔒 |
| Q2 — Canary vs Blue-Green | **7.5/10** | — |
| Q3 — AnalysisTemplate deep-dive | **7.0/10** | — |
| Q4 — Rollback flow | **7.0/10** | — |
| Q5 — Why manual approval gate | **8.0/10** 🔒 | — |

**Phase 5 Final Average (Q1 R2 + Q2 + Q3 + Q4 + Q5): 7.5/10**
