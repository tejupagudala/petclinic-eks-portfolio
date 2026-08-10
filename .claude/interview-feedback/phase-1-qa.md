# Phase 1 — Q&A Drilled Bank

**Phase 1 average score across 5 hostile questions: 7.7/10**

Companion to [phase-1-reference.md](phase-1-reference.md). Reference file = concepts + cheat card. This file = hostile Q&As, ideal answers, and follow-ups.

---

## Table of Contents

- [Q1: "Walk me through your CI/CD pipeline end to end"](#q1-walk-me-through-your-cicd-pipeline-end-to-end)
- [Q2: "Why update the K8s manifest from CI instead of kubectl apply directly?"](#q2-why-update-the-k8s-manifest-from-ci-instead-of-kubectl-apply-directly)
- [Q3: "Why scan the Docker image BEFORE push instead of after?"](#q3-why-scan-the-docker-image-before-push-instead-of-after)
- [Q4: "Why github.run_id as image tag — why not git SHA?"](#q4-why-githubrun_id-as-image-tag--why-not-git-sha)
- [Q5: "What happens if your updatek8s commit fails — green or red?"](#q5-what-happens-if-your-updatek8s-commit-fails--green-or-red)

---

## Q1: "Walk me through your CI/CD pipeline end to end"

**Round 1 — 2026-05-17 — Score: 8.5/10**

**What Sai got right:**
- ✅ Cited `qualitygate.wait=true` AND explained the consequence (blocking vs advisory)
- ✅ Trivy with explicit CVSS ≥ 7 threshold + `exit-code: 1` + `ignore-unfixed`
- ✅ Scan-before-push pattern (build without pushing → scan → push)
- ✅ GitOps invariant: "git and cluster always match"
- ✅ Fork protection guard mentioned
- ✅ Bot user pattern for auto-commit
- ✅ Strong close: "automation default, manual only when genuinely needed"

**What to fix to reach 9.5+:**
- Name **Java 17 Temurin** explicitly
- Cite **Maven multi-module flags `-pl spring-petclinic-api-gateway -am`**
- Mention **two-tag strategy** (`github.run_id` + `latest`)
- Explain **skip-tests-then-test pattern** ("fast failure on compile errors")
- Add timing: **"4-5 minutes end to end"**
- Tighten run-on sentences (one sentence per job)
- Correct "PR for every code change on main" → **"PRs targeting main"**

**Ideal answer (~95 seconds spoken, 130 words):**

> *"My CI pipeline lives in `.github/workflows/ci.yaml`. It triggers on pull requests targeting main, paths-filtered to `app/`, `kubernetes/api-gateway/`, `terraform/`, or the workflow file itself.*
>
> *Five jobs run in this order: First, **build** — Java 17 Temurin, Maven multi-module with `-pl spring-petclinic-api-gateway -am`, skip tests for fast failure, then run tests separately. In parallel, **code-quality** runs SonarCloud with JaCoCo coverage, gated by `qualitygate.wait=true` — the workflow blocks until SonarCloud returns pass/fail, so it's a real gate, not advisory.*
>
> *After both succeed, **security-scan** runs Trivy in three modes — filesystem, Kubernetes config, Terraform config — all set to exit-1 on HIGH or CRITICAL CVEs, CVSS ≥ 7. Then **docker** — buildx, login, build WITHOUT pushing, Trivy image scan, only THEN push with two tags: `github.run_id` for immutability and `latest` for convenience.*
>
> *Finally, **updatek8s** sed-replaces the image tag in the Kubernetes manifest and commits to the PR branch as a bot user. Once the PR merges to main, Argo CD picks up the new manifest and reconciles the cluster — that's the GitOps separation of concerns: CI builds and updates git, CD deploys from git. The whole pipeline takes about 4-5 minutes."*

**Secret weapon phrases:**
- *"GitOps separation of concerns: CI builds and updates git, CD deploys from git"*
- *"qualitygate.wait=true — it's a real gate, not advisory"*
- *"Scan-before-push — registry is a trust boundary"*
- *"`github.run_id` for immutability and `latest` for convenience"*

**Likely hostile follow-ups:**
- *"Why update the K8s manifest from CI instead of `kubectl apply` directly?"* → See Q2
- *"Why scan the Docker image BEFORE push?"* → See Q3
- *"Why `github.run_id` as image tag?"* → See Q4
- *"What happens if updatek8s commit fails?"* → See Q5

---

## Q2: "Why update the K8s manifest from CI instead of kubectl apply directly?"

**Round 1 — 2026-05-18 — Score: 7/10**
**Round 2 — 2026-05-18 — Score: 9/10** 🔒

**What Sai got right in R2:**
- ✅ Stated full pain inventory (slow, error-prone, no audit, no quality gates, non-reproducible)
- ✅ Used "single source of truth" terminology
- ✅ Named the reconciliation mechanic
- ✅ Connected direct-apply to credential sprawl (security)
- ✅ Connected debugging to `git log`
- ✅ Strong 5-attribute close
- ✅ Drift detection mechanism with concrete polling interval

**What to fix to reach 10/10:**
- ❌ Structural repetition (stated pain points twice in R1)
- Missed "**CI builds and updates git; CD deploys from git**" (separation of concerns phrasing)
- Missed "**rollback becomes `git revert`**" (operational payoff)
- Didn't explicitly contrast push vs pull deployment models
- Didn't mention multi-cluster benefit (same git, different reconcilers)

**Ideal answer (~80 seconds spoken):**

> *"If CI ran `kubectl apply` directly, CI would need cluster credentials — and that creates three problems. First, security: credentials in CI mean if my CI is compromised, the attacker controls the cluster. Second, state drift: someone could `kubectl edit` something manually and the cluster would diverge from git, with no way to know what's actually running. Third, disaster recovery: I couldn't rebuild the cluster from git if git wasn't actually driving the cluster state.*
>
> *Instead, I use the GitOps pattern — separation of concerns: CI builds and updates git; CD deploys from git. My CI updates the image tag in the Kubernetes manifest and commits it. Argo CD, running inside the cluster, pulls from git and reconciles the cluster to match. The cluster has credentials to Argo CD's identity; my CI has zero cluster credentials.*
>
> *The operational payoff is huge: rollback becomes `git revert` instead of manually figuring out the previous image tag. Audit is `git log` — every deployment is a commit with an author. Argo CD's UI shows drift in real time — if anything in the cluster doesn't match git, I see it immediately. And if I add a second cluster tomorrow, I just point another Argo CD at the same git repo — same source of truth, different reconcilers."*

**Secret weapon phrases:**
- *"CI builds and updates git; CD deploys from git"* — GitOps in 10 words
- *"Rollback becomes `git revert`"* — operational payoff one-liner
- *"Push-based vs pull-based deployment"* — proper GitOps vocabulary
- *"Argo CD detects drift in real time"* — unique GitOps superpower
- *"Same git, different reconcilers"* — multi-cluster benefit

**Likely hostile follow-ups:**
- *"What happens when Argo CD itself goes down?"* → Cluster keeps running current state; reconciliation pauses; CD failure ≠ service outage
- *"How long is the reconciliation interval?"* → 3 minutes default; webhook-triggered for faster
- *"What about secrets — do you keep them in git too?"* → No, use Sealed Secrets or External Secrets Operator for that

---

## Q3: "Why scan the Docker image BEFORE push instead of after?"

**Round 1 — 2026-05-18 — Score: 7.5/10**

**What Sai got right:**
- ✅ The mechanic precisely: `load: true, push: false` in local Docker daemon
- ✅ Lazy vs modern contrast named
- ✅ Loss-of-control argument
- ✅ Blast radius statement (HIGH/critical bugs can never go into Docker hub)
- ✅ Exit-code mechanism (gate enforcement)

**What to fix to reach 9+/10:**
- Name **"the registry is a trust boundary"** (the killer phrase)
- Differentiate **defense in depth** — FS scan vs IMAGE scan catch DIFFERENT things
- Open with the comparison directly, not generic Trivy framing
- Cite a real CVE example (Log4Shell)
- Mention NIST SSDF / CISA supply chain recommendations

**Ideal answer (~75 seconds):**

> *"Scan-after-push is the lazy default — the image is already in the registry before you know it's bad. Anyone with pull access can grab it, K8s pods can deploy it, an attacker analyzing the registry can find the CVE. The registry is a trust boundary; once you've crossed it, you've lost control.*
>
> *Scan-before-push reverses that. My pipeline does `build` with `push: false, load: true` — the image goes into the runner's local Docker daemon, never DockerHub. Trivy scans it there. If it finds HIGH or CRITICAL CVEs with available fixes, exit-1 fails the job. Only if the scan passes does the next step run `push: true`. A bad image never reaches the registry, so nothing in the cluster can pull it.*
>
> *This also gives me defense in depth alongside the FS scan. FS scan catches source-level dependencies in my pom.xml. Image scan catches what's actually baked in — base image vulns from `eclipse-temurin:17`, transitive packages, OS-level libs. A clean FS scan doesn't mean a clean image. Imagine my base image bundled Log4Shell — CVE-2021-44228, CVSS 10.0. FS scan would never see it because it's not in my source. Image scan catches it before publish.*
>
> *This is what NIST SSDF and CISA recommend for supply chain security — gate the registry, not just the dashboard."*

**Secret weapon phrases:**
- *"The registry is a trust boundary"*
- *"Defense in depth — different attack surfaces"*
- *"NIST SSDF / CISA recommended pattern"*
- *"Gate the registry, not just the dashboard"*

**Likely hostile follow-ups:**
- *"What if the CVE is in your base image — how do you fix?"* → Update base image version, rebuild
- *"How often does the Trivy DB update?"* → Daily by default; can be configured
- *"What about ImageStreams / signed images?"* → Cosign for signing, Notary for verification — next-level supply chain security

---

## Q4: "Why github.run_id as image tag — why not git SHA?"

**Round 1 — 2026-05-18 — Score: 7/10**

**What Sai got right:**
- ✅ run_id maps 1:1 to CI run (traceability)
- ✅ Reproducibility argument (look at JaCoCo, Trivy results)
- ✅ Monotonically increasing (chronological)
- ✅ Hinted at imagePullPolicy issue with `:latest`

**What to fix to reach 9+/10:**
- ❌ MAJOR: Never addressed git SHA explicitly (the question asked!)
- Missed: All 3 reasons `:latest` is bad (rollback, audit, pull semantics)
- Missed: "Content-addressable identity"
- Missed: Hybrid pattern (some teams use SHA-runid)
- "conflicts" wording slip (probably meant "no conflicts")

**Ideal answer (~60 seconds):**

> *"There are three candidates for an immutable tag: git SHA, github.run_id, and semver. I chose run_id for three reasons.*
>
> *First, run_id maps 1:1 to a CI run — git SHA only maps to a commit. The same SHA can be built multiple times: workflow re-runs, branch rebuilds, manual dispatches. With SHA as the tag, two different images could share the same tag — you lose the 1:1 build-to-image guarantee. With run_id, every image has exactly one CI run that produced it.*
>
> *Second, traceability — paste any run_id into the GitHub Actions UI and I see everything that happened: which tests passed, which JaCoCo coverage report applied, which Trivy CVEs were scanned, who opened the PR. The run_id is the canonical link between an image and its provenance.*
>
> *Third, monotonic ordering — newer run_id is always a larger number, so I can read deployment history chronologically without parsing dates.*
>
> *And I never use `:latest` in Kubernetes manifests — it breaks rollback because you can't pin to a previous image, breaks audit because `kubectl describe` doesn't tell you which build is running, and breaks pull semantics because `imagePullPolicy: IfNotPresent` won't re-pull. The two-tag strategy — `run_id` for the manifest, `:latest` for local dev convenience — gives me reproducibility in production and ergonomics in dev."*

**Key insight:** Always address the comparison the question makes (git SHA in this case).

**Secret weapon phrases:**
- *"run_id is the canonical link between an image and its provenance"*
- *"Content-addressable identity"*
- *"`:latest` breaks rollback, audit, and pull semantics"*

**Likely hostile follow-ups:**
- *"What if the workflow re-runs and produces a different image?"* → Each re-run gets a new run_id, so the image identity is unique
- *"Could you use Docker image digests instead?"* → Yes, even more immutable; tradeoff is digests are unreadable hex strings
- *"How do you garbage-collect old images in DockerHub?"* → Lifecycle rules on DockerHub or ECR can auto-delete tags older than X days

---

## Q5: "What happens if your updatek8s commit fails — green or red?"

**Round 1 — 2026-05-18 — Score: 6.5/10**

**What Sai got right:**
- ✅ Red workflow status (correctly tied to consequence)
- ✅ The partial-state recognition (image in DockerHub, manifest not updated)
- ✅ Recovery path via re-run

**What costs the 3.5 points:**
- ❌ **MAJOR error:** "PR can be merged manually" — wrong! Branch protection should block; merging without manifest update silently ships nothing
- ❌ Missed the `|| echo "No changes to commit"` idempotency guard
- ❌ Missed the `if:` guard preventing worst partial state
- ❌ Missed the word "idempotent"
- ❌ Confidence wobble at start ("I am not sure")

**Ideal answer (~75 seconds):**

> *"It depends on which step failed. If `git push` fails — auth error, network issue, branch protection — the job fails, the workflow is red, the PR check is red, and branch protection blocks the merge.*
>
> *State at that point: the Docker image IS in DockerHub (the docker job succeeded before updatek8s ran), but the K8s manifest in git was NOT updated. That's a partial-success state.*
>
> *Recovery is simple because the pipeline is designed to be idempotent: I fix the issue — refresh the GITHUB_TOKEN, fix branch protection, whatever — and re-run the workflow. The `sed` step is idempotent so it doesn't matter if it runs again. The `git commit` step has a `|| echo 'No changes to commit'` guard, so if it re-runs without changes it still passes. The image push just overwrites the immutable `run_id` tag with the same image. Once the workflow goes green, the manifest is updated, the PR can be merged, and Argo CD picks up the change.*
>
> *Importantly, I have an `if: needs.docker.result == 'success'` guard on the updatek8s job — that prevents the WORST partial state where you'd update the manifest pointing to an image that doesn't exist in the registry. Updatek8s only runs if the image is confirmed pushed."*

**Critical correction:** DO NOT merge the PR manually if updatek8s failed. Branch protection should block it; merging without manifest update silently ships nothing.

**Secret weapon phrases:**
- *"Idempotent recovery"* — design principle name
- *"Partial-success state is recoverable"* — fail-safe framing
- *"The `if:` guard prevents the worst partial state"* — protection awareness
- *"The `|| echo 'No changes to commit'` is defensive idempotency"*

**Likely hostile follow-ups:**
- *"What if the docker push succeeded but with a typo in the tag — how do you recover?"* → run_id is auto-generated, no typo possible; if manifest sed had a typo, fix and re-run
- *"How do you alert on workflow failures?"* → GitHub Actions notifications, or wire to Slack/PagerDuty via webhook
- *"Could Argo CD partially apply if the manifest is malformed?"* → Argo CD's sync hooks (PreSync, Sync, PostSync) handle ordering; failed sync = nothing applied + visible in dashboard

---

## Phase 1 — Trajectory Summary

| Question | Round 1 | Round 2 (if applicable) |
|---|---|---|
| Q1 — CI/CD walkthrough | **8.5/10** | — |
| Q2 — Why GitOps | 7/10 | **9/10** 🔒 |
| Q3 — Scan before push | **7.5/10** | — |
| Q4 — run_id vs SHA | **7/10** | — |
| Q5 — updatek8s failure modes | **6.5/10** | — |

**Phase 1 average: 7.7/10** — interview-viable at $120-165K band.

**Best score:** Q2 R2 (9/10) — GitOps philosophy with all secret weapons landed.
**Lowest:** Q5 (6.5/10) — failure-mode question; needs re-attempt with idempotency framing.

---

## 📚 Phase 1 — Follow-up Answer Bank

Full ideal answers (not one-liners) for every hostile follow-up across Q1-Q5.

---

### Q1 Follow-ups (CI/CD pipeline)

**Q1.F1: "Why update the K8s manifest from CI instead of `kubectl apply` directly?"**
> *"Three problems with `kubectl apply` from CI. One — security: CI would need cluster credentials. If CI is compromised, the attacker controls the cluster. Two — state drift: someone could `kubectl edit` manually and the cluster diverges from git with no audit trail. Three — disaster recovery becomes impossible — can't rebuild from git if git isn't actually driving cluster state. The GitOps pattern fixes all three: CI builds and updates git; Argo CD running inside the cluster pulls from git and reconciles. CI has zero cluster credentials. Rollback becomes `git revert`. Audit is `git log`. (Full answer in Q2 ideal.)"*

**Q1.F2: "Why scan the Docker image BEFORE push?"**
> *"The registry is a trust boundary — once you push, you've lost control. Anyone with pull can grab the image; pods can deploy it; attackers analyzing the registry find the CVE. Scan-after-push is the lazy default. Trivy with `exit-code: 1` on HIGH/CRITICAL fails the workflow BEFORE the push step runs — bad images never enter the registry. Defense in depth: I also scan the filesystem separately for app-layer CVEs that wouldn't appear in the image scan. (Full answer in Q3 ideal.)"*

**Q1.F3: "Why `github.run_id` as image tag?"**
> *"Immutable identity. Every workflow run gets a unique run_id from GitHub — can't be reused, can't be overwritten. The image identity becomes auditable: tag → run_id → commit SHA → PR → author → review chain. `latest` is convenience for local pulls; production references the run_id tag explicitly so a rollback knows exactly which image version to deploy. Docker image digests are even more immutable but the SHA-256 hex string is unreadable for humans. (Full answer in Q4 ideal.)"*

**Q1.F4: "What happens if updatek8s commit fails?"**
> *"The workflow fails red — no manifest update means no deploy. The image was already pushed to the registry but it's not referenced anywhere in git, so Argo CD won't pick it up. Recovery is a manual `kubectl set image` for emergency, but the right fix is to re-run the workflow which gets a new run_id and tries the commit again. Idempotency is the key — the workflow can be re-run safely. (Full answer in Q5 ideal.)"*

---

### Q2 Follow-ups (GitOps + Argo CD)

**Q2.F1: "What happens when Argo CD itself goes down?"**
> *"The cluster keeps running its current state — Argo CD doesn't run any workloads, it just reconciles. Reconciliation pauses; deploys queue up. CD failure ≠ service outage. When Argo CD comes back, it resumes reconciliation from current git state. If Argo CD is down for a long period, you might miss a critical deploy — but that's a separate alarm condition. Production fix: Argo CD HA mode with 3 replicas across AZs; CloudWatch alarm on Argo CD pod count below replica target."*

**Q2.F2: "How long is the reconciliation interval?"**
> *"Default 3 minutes — Argo CD polls git every 3 minutes and compares to cluster state. For faster reaction, configure a webhook from GitHub to Argo CD: push to main triggers immediate reconciliation. Interval is tunable per Application via the `syncPolicy.automated` block. For my portfolio I rely on the default 3-minute poll. Production with critical SLAs would use webhooks for sub-minute reaction."*

**Q2.F3: "What about secrets — do you keep them in git too?"**
> *"No — never plaintext secrets in git. Two production patterns. Sealed Secrets: encrypt secrets with a cluster-side private key; encrypted ciphertext is safe in git, decryption happens at apply time inside the cluster. External Secrets Operator: keep secrets in AWS Secrets Manager (or Vault), ESO syncs to K8s Secrets at runtime. For my portfolio Phase 6 uses the bootstrap-workflow-fetches-from-Secrets-Manager pattern as a portfolio shortcut; production fix is ESO so rotation works."*

---

### Q3 Follow-ups (Trivy scan-before-push)

**Q3.F1: "What if the CVE is in your base image — how do you fix?"**
> *"Update the base image version. My Dockerfile uses `eclipse-temurin:17` — when a CVE drops, I bump to a newer patch version like `17.0.10` or switch to a different distro (`-alpine` for smaller, `-jammy` for newer Ubuntu). Rebuild, rescan, redeploy. Production fix: use Dependabot or Renovate to auto-PR base image bumps; CI re-runs Trivy on every base image change. For severity, I'd add Trivy CVE allowlist for known-false-positives to prevent CI thrash."*

**Q3.F2: "How often does the Trivy DB update?"**
> *"Daily by default — Trivy pulls vulnerability data from NVD, GitHub Advisory Database, and OS vendor feeds on each scan. The DB is cached locally with a 12-hour staleness threshold. Config via `--cache-dir` for persistent caching in CI to avoid re-downloading the full DB every run. Production: pre-warm the cache in a base CI image to keep scans under 30 seconds."*

**Q3.F3: "What about ImageStreams / signed images?"**
> *"Image signing is the next-level supply-chain security pattern. Cosign signs images at build time with a private key; Notary or Kyverno enforce admission policy that pods can only run from signed images. Combined with Trivy scanning, you get end-to-end provenance: signed-by-CI + scanned-clean + matched-to-git-commit. For my portfolio I don't sign — production trigger is any compliance requirement or supply-chain audit (SOC2, FedRAMP). Sigstore is the modern free option."*

---

### Q4 Follow-ups (`github.run_id` tagging)

**Q4.F1: "What if the workflow re-runs and produces a different image?"**
> *"Each re-run gets a new `run_id` — GitHub guarantees uniqueness. So the new image has a different tag, different identity. The previous run_id tag still exists in the registry pointing at the previous image. If you re-run because the first push succeeded but updatek8s failed, the new image identity is what gets committed. Production: GitHub run_id IS the build identity; nothing is overwritten. Identity preservation enables clean rollback to any historical run_id."*

**Q4.F2: "Could you use Docker image digests instead?"**
> *"Yes — digests are even more immutable than tags. A digest is `sha256:...` over the image manifest. Same digest = byte-identical image; impossible to tamper. Tradeoff: `sha256:abc123...` is unreadable for humans, hard to type during incident response. Best of both: use run_id as the human-readable tag PLUS reference digest in production manifests for tamper detection. Production fix: Kyverno admission policy that requires pods to reference images by digest, not tag."*

**Q4.F3: "How do you garbage-collect old images in DockerHub?"**
> *"DockerHub has lifecycle rules: auto-delete tags older than N days, or auto-delete tags beyond N most-recent. ECR has the same via ECR Lifecycle Policies. For my portfolio I keep everything (cheap at this scale). Production: keep last 30 days of tags + all release tags forever. Tradeoff: rollback to a 6-month-old version requires resurrecting the image from somewhere — backup to S3 if compliance requires long-term image retention."*

---

### Q5 Follow-ups (CI failure handling)

**Q5.F1: "What if the docker push succeeded but with a typo in the tag — how do you recover?"**
> *"run_id is auto-generated by GitHub — no typo possible at the tag layer. If the manifest sed had a typo (e.g., wrong service name), the commit lands but Argo CD fails to find the deployment. Detection: Argo CD shows OutOfSync or SyncFailed; PR check stays red. Recovery: fix the typo in a new PR, push to main, workflow re-runs with new run_id, valid manifest. Idempotency makes this safe — no manual cleanup needed."*

**Q5.F2: "How do you alert on workflow failures?"**
> *"Three layers. GitHub Actions emits failure notifications to the workflow owner by default — email, GitHub UI red badge. Wire to Slack via the official GitHub Actions Slack integration for team-level visibility. Wire to PagerDuty via webhook for on-call escalation on production-critical workflows like `infra-bootstrap` or canary deploys. For my portfolio I use email + Slack; production needs PagerDuty for any workflow that gates user impact."*

**Q5.F3: "Could Argo CD partially apply if the manifest is malformed?"**
> *"Argo CD uses sync phases — PreSync, Sync, PostSync — and applies resources in dependency order. If a malformed manifest fails the API server's validation, the sync hook fails and the whole sync is marked SyncFailed. No partial apply because each phase commits atomically. Visible in the Argo CD dashboard with the specific error message from the K8s API. Recovery: fix the manifest, push, Argo CD retries on next sync window (3 min default)."*

---
