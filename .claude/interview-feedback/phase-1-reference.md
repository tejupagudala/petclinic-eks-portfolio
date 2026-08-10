# Phase 1 — Foundation & CI Scaffold (COMPLETE REFERENCE)

**Window:** Feb 23 → Mar 13, 2026 (~3 weeks)
**Final Average Score:** 7.7/10 across 5 hostile interview questions
**Status:** ✅ Locked — interview-viable

This is your **complete reference** for Phase 1. Everything covered in training is captured here for future review.

---

## 📑 Table of Contents

1. [The Story (Why / What / Fails / Wins)](#the-story)
2. [Architecture Decisions Explained](#architecture-decisions)
3. [The 5-Job CI Pipeline Deep Dive](#the-5-job-pipeline)
4. [ci.yaml Complete Walkthrough](#ciyaml-walkthrough)
5. [Foundation Concepts](#foundation-concepts)
6. [5 Hostile Interview Q&A (Drilled)](#hostile-qa)
7. [8 Follow-Up Q&A (Quick-Fills)](#followup-qa)
8. [Power Phrases & Secret Weapons](#power-phrases)
9. [Common Mistakes to Avoid](#common-mistakes)
10. [Cheat Card](#cheat-card)

---

<a name="the-story"></a>
## 1. The Story (Why / What / Fails / Wins)

### Why Phase 1 Existed

Before deploying anything to AWS, before canary rollouts or AIOps assistants, you needed a working pipeline. Phase 1 is the foundation everything else stacks on.

**The problem you were solving:**
- You had application code (Spring Petclinic — an open-source reference architecture)
- You needed to ship it to a cluster repeatedly, reliably, and safely
- Manual `mvn package && docker build && kubectl apply` is the junior approach — error-prone, no audit trail, no quality gates

Phase 1 answered: **"How do I make a change to my code and have it land in the cluster without me touching the cluster?"**

The senior answer: **a CI/CD pipeline with GitOps separation of concerns** — CI builds and updates git; CD (Argo CD) reconciles the cluster to git. CI never runs `kubectl apply`.

### What Got Built

**Commit `24e59dc` — Feb 23, 2026:** "Set up portfolio structure"

You forked the Spring Petclinic Microservices reference architecture and created 4 clean top-level directories:

```
petclinic-eks-portfolio/
├── app/              # 6 Spring Boot microservices (Maven multi-module)
│   ├── pom.xml       # Parent POM with shared config
│   ├── spring-petclinic-api-gateway/
│   ├── spring-petclinic-customers-service/
│   ├── spring-petclinic-vets-service/
│   ├── spring-petclinic-visits-service/
│   ├── spring-petclinic-discovery-server/
│   ├── spring-petclinic-config-server/
│   └── docker/Dockerfile    # Shared multi-stage Dockerfile
├── terraform/        # IaC placeholder (Phase 3 fills this)
├── kubernetes/       # Manifests
└── .github/workflows/ # CI/CD pipelines
```

**The Spring Stack:**
- Java 17 (Eclipse Temurin distribution)
- Spring Boot 4.0.1
- Spring Cloud 2025.1.0 (for service discovery via Eureka, distributed config via Config Server)
- Maven multi-module

### The Fails (Honest Story)

| Date | Commit | What broke |
|------|--------|-----------|
| Feb 23 | `6d47b50` → `a03bd87` | **5 commits in one day** trying to get GitHub Actions YAML indentation right |
| Feb 24 | `e070b14` | "fix: restore ci workflow content" — accidentally wiped the workflow file |
| Feb 24 | `a05a344` | "random change to pom.xml test" — manually triggering CI to verify |

**The honest interview tell:**
> *"It took me 5 iterations to get the GitHub Actions paths-filter syntax right. I was new to it. By the 5th iteration I had a working pipeline. That was my first lesson in Actions YAML — indentation is sacred."*

### The Wins

| Date | Commit | What landed |
|------|--------|------------|
| Feb 23 | `ad8cbc1` | **First successful CI run — image tag auto-updated in `vets-service` manifest.** The "pipeline is alive" moment. |
| Feb 24 | `68c8ae7` | "docs: add full rebuild, teardown, and completion runbook" — **wrote ops docs before the project was half-built.** Operational maturity signal. |
| Mar 13 | `1a2cddb` | Multiple successful pipeline runs across services. Ready for Phase 2. |

---

<a name="architecture-decisions"></a>
## 2. Architecture Decisions Explained

### Why CI Targets Only `api-gateway`

The `ci.yaml` workflow only builds api-gateway, not all 6 microservices. **This is intentional, not oversight.**

**Defensible reasons:**

1. **api-gateway is the user-facing entry point** — all external traffic flows through it. Blast radius of a bad deploy is 5-10x higher than internal services.
2. **api-gateway is the canary target** — it's the only service running as an Argo Rollout (Phase 5). The CI/CD pipeline integrates with progressive delivery — more complex than backend services need.
3. **Portfolio scope decision** — building 6 identical pipelines = copy-paste waste. Prove the pattern in one service, then templatize.
4. **The other services rarely change** — backend services (vets, customers, visits) are stable CRUD. CI on stable services delivers less value per runner-minute.

**Interview-grade extension answer:**
> *"To extend this to all 6 services, I'd refactor `ci.yaml` into a reusable workflow using `workflow_call`, parameterized by service name. Each service would have a thin trigger workflow that calls the shared pipeline. That's DRY, easy to maintain, and changing the pipeline is a one-file change instead of six."*

### Why GitOps (Manifest Update) Instead of Direct kubectl apply

**Three problems with direct `kubectl apply` from CI:**

1. **Security** — CI needs cluster credentials. Compromised CI = compromised cluster.
2. **State drift** — someone could `kubectl edit` manually; cluster diverges from git silently.
3. **Disaster recovery** — can't rebuild the cluster from git if git wasn't driving cluster state.

**The GitOps fix:**
- CI builds and updates git (manifest tag bump)
- Argo CD (running inside the cluster) pulls from git and reconciles
- Cluster has Argo CD's identity; CI has zero cluster credentials

**Operational payoffs:**
- Rollback = `git revert`
- Audit = `git log` (every deployment is a commit)
- Drift detection — Argo CD UI shows out-of-sync resources in real time
- Multi-cluster — point another Argo CD at the same git repo

### Why Scan Image BEFORE Push

The senior security move: load image into local Docker daemon → scan → push only if clean.

**Scan-after-push (lazy):** Image already in registry. Bad image is technically "shipped."
**Scan-before-push (gate):** Image never crosses the registry trust boundary if it has HIGH/CRITICAL CVEs.

**Mechanic in your pipeline:**
```yaml
- name: Build image
  uses: docker/build-push-action@v6
  with:
    push: false        # ← DO NOT publish yet
    load: true         # ← Load into local Docker daemon
    tags: ...

- name: Trivy image scan
  uses: aquasecurity/trivy-action@v0.25.0
  with:
    image-ref: ...
    exit-code: '1'     # ← FAIL if HIGH/CRITICAL found

- name: Push image
  uses: docker/build-push-action@v6
  with:
    push: true         # ← Only reached if scan passed
```

**Defense in depth:** FS scan catches dependencies in source (`pom.xml`). Image scan catches what's actually baked in (base image vulns from `eclipse-temurin:17`, OS libs, transitive packages).

### Why `github.run_id` as Image Tag (Not Git SHA)

**Three candidates for immutable tags:** git SHA, github.run_id, semver.

**Why run_id wins:**

1. **Maps 1:1 to a CI run** — git SHA only maps to a commit. Same SHA can be built multiple times (workflow re-runs, branch rebuilds). With SHA, two different images could share the same tag.
2. **Traceability** — paste run_id into GitHub Actions UI → see all jobs, logs, scan results, tests, who opened the PR.
3. **Monotonically increasing** — newer image = larger number. Read chronologically without parsing dates.

**Never use `:latest` in Kubernetes manifests** — breaks rollback, audit, pull semantics, and deployment change detection.

**Two-tag strategy:** `run_id` for K8s manifests (immutable production identity), `latest` for local dev convenience only.

---

<a name="the-5-job-pipeline"></a>
## 3. The 5-Job CI Pipeline Deep Dive

| Job | What it does | Why it's senior-coded |
|-----|--------------|------------------------|
| **1. build** | Java 17 Temurin → Maven `-pl spring-petclinic-api-gateway -am clean package -DskipTests` → then `mvn test` | Build fails fastest. Tests separate from build so a compile error doesn't waste test time. |
| **2. code-quality** | SonarCloud + JaCoCo coverage with `sonar.qualitygate.wait=true` | The `wait=true` flag makes SonarCloud a **blocking gate** — workflow halts until pass/fail returns. |
| **3. security-scan** *(needs: build, code-quality)* | Trivy in 3 modes: filesystem on `app/`, config on `kubernetes/api-gateway/`, config on `terraform/`. All `exit-code: 1` on HIGH/CRITICAL | Three scan modes catch app vulns + K8s misconfigs + IaC misconfigs. |
| **4. docker** *(needs: build, security-scan)* | Buildx → DockerHub login → build WITHOUT pushing → **Trivy IMAGE scan** → THEN push with two tags (`run_id` + `latest`) | Senior move: scan after build, before push. If image has HIGH CVEs, never reaches registry. |
| **5. updatek8s** *(needs: build, docker, code-quality)* | `sed -i` the image tag in `kubernetes/api-gateway/deploy.yaml` → commit → push to PR branch | **GitOps pattern.** CI doesn't `kubectl apply`. Updates manifest in git. Argo CD picks it up. |

### The `updatek8s` Job's 3-Guard `if:` Condition

```yaml
if: needs.docker.result == 'success'      # Guard 1
    && github.event_name == 'pull_request'  # Guard 2
    && github.event.pull_request.head.repo.full_name == github.repository  # Guard 3
```

| Guard | Prevents |
|---|---|
| `needs.docker.result == 'success'` | **Operational disaster** — manifest pointing to non-existent image → ImagePullBackOff in prod |
| `github.event_name == 'pull_request'` | **Crash** — undefined `head_ref` variable on non-PR events |
| `head.repo.full_name == github.repository` | **Security breach** — forked PR exploiting your bot token ("pwn request" attack) |

### The Multi-Stage Dockerfile

```dockerfile
FROM eclipse-temurin:17 AS builder
WORKDIR application
COPY ${ARTIFACT_NAME}.jar application.jar
RUN java -Djarmode=layertools -jar application.jar extract  # ← splits JAR into layers

FROM eclipse-temurin:17
WORKDIR application
COPY --from=builder application/dependencies/ ./           # ← 80% of size, rarely changes
COPY --from=builder application/spring-boot-loader/ ./
COPY --from=builder application/snapshot-dependencies/ ./
COPY --from=builder application/application/ ./             # ← your code, changes often
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
```

**The `layertools` trick:** Spring Boot fat JAR is ~150MB. Without layertools, every code change rebuilds the entire 150MB layer. With layertools split into 4 layers, **code-change rebuilds drop from ~150MB to ~2MB.**

---

<a name="ciyaml-walkthrough"></a>
## 4. ci.yaml Complete Walkthrough

### How GitHub Knows to Run This Workflow

There's NO connection code. GitHub Actions is a built-in feature of every github.com repo:
- GitHub scans `.github/workflows/` directory automatically
- Any `.yml` or `.yaml` file is registered as a workflow
- The `on:` block tells GitHub WHEN to run it

Verification: `https://github.com/tejupagudala/petclinic-eks-portfolio/actions`

Secrets storage: `github.com/<repo>/settings/secrets/actions` — encrypted at rest using libsodium sealed boxes, injected at runtime, auto-redacted from logs.

### The Header Block

```yaml
name: api-gateway-ci      # Display name in GitHub UI
```

### The Trigger Block

```yaml
on:
  pull_request:
    branches: [ main ]
    paths:
      - "app/**"
      - "kubernetes/api-gateway/**"
      - "terraform/**"
      - ".github/workflows/ci.yaml"
```

**Reads as:** *"Run on PRs targeting `main`, ONLY if changed files match these 4 paths."*

**Industry benchmark:** Paths-filter cuts unnecessary builds by **40-60%** on monorepos.

### The Permissions Block

```yaml
permissions:
  contents: write
```

**Principle of least privilege.** Default `GITHUB_TOKEN` is read-only. `contents: write` is required because the `updatek8s` job commits back to the PR branch. Without it, `git push` would fail with 403.

### The Environment Block

```yaml
env:
  SERVICE_NAME: api-gateway
  DOCKER_IMAGE: ${{ secrets.DOCKER_USERNAME }}/api-gateway
```

Workflow-wide environment variables available in every job.

### Job 1 — `build`

```yaml
build:
  runs-on: ubuntu-latest
  steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Java 17
      uses: actions/setup-java@v4
      with:
        distribution: temurin
        java-version: "17"
        cache: maven        # ← Uses GitHub Cache for ~/.m2/repository

    - name: Build (skip tests)
      run: |
        cd app
        ./mvnw -pl spring-petclinic-api-gateway -am clean package -DskipTests

    - name: Unit tests
      run: |
        cd app
        ./mvnw -pl spring-petclinic-api-gateway -am test
```

**Why skip tests then re-run?** Speed of feedback. Build fails (compile error) in 30 sec instead of 5 min through tests.

### Job 2 — `code-quality` (runs in PARALLEL with build)

```yaml
code-quality:
  runs-on: ubuntu-latest
  steps:
    - Checkout code
    - Setup Java 17
    - name: SonarQube/SonarCloud Static Code Analysis
      env:
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
        SONAR_PROJECT_KEY: ${{ secrets.SONAR_PROJECT_KEY }}
        SONAR_ORG: ${{ secrets.SONAR_ORG }}
      run: |
        ./mvnw -pl spring-petclinic-api-gateway -am verify sonar:sonar \
          -Dsonar.coverage.jacoco.xmlReportPaths=...jacoco.xml \
          -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
          -Dsonar.organization="$SONAR_ORG" \
          -Dsonar.host.url="$SONAR_HOST_URL" \
          -Dsonar.token="$SONAR_TOKEN" \
          -Dsonar.qualitygate.wait=true   # ← THE KEY FLAG
```

**The Maven command does TWO things:**
1. `verify` triggers JaCoCo to generate `jacoco.xml` (coverage report)
2. `sonar:sonar` uploads source + coverage XML to SonarCloud

**`qualitygate.wait=true`** = blocking gate. Workflow halts until SonarCloud returns pass/fail.

### Job 3 — `security-scan` (needs: build, code-quality)

```yaml
security-scan:
  runs-on: ubuntu-latest
  needs: [build, code-quality]
  steps:
    - Checkout code
    - Trivy FS scan (app/)
    - Trivy config scan (kubernetes/api-gateway/)
    - Trivy config scan (terraform/)
```

Each Trivy step:
```yaml
- uses: aquasecurity/trivy-action@v0.25.0
  with:
    scan-type: fs/config
    scan-ref: ...
    severity: HIGH,CRITICAL       # Only fail on CVSS ≥ 7.0
    ignore-unfixed: true          # Skip CVEs with no patch available
    exit-code: '1'                # Fail build on any match
```

### Job 4 — `docker` (needs: build, security-scan)

```yaml
docker:
  runs-on: ubuntu-latest
  needs: [build, security-scan]
  steps:
    - Checkout code
    - Set up Docker Buildx
    - Login to DockerHub
    - Build image (push: false, load: true)    # ← NOT pushed yet
    - Trivy IMAGE scan                          # ← gate
    - Push image (push: true) with TWO tags    # ← only if scan passes
      tags: |
        ${{ env.DOCKER_IMAGE }}:${{ github.run_id }}
        ${{ env.DOCKER_IMAGE }}:latest
```

**Buildx** is Docker's modern BuildKit-based engine. Gives multi-platform builds, better caching, and the `load: true, push: false` pattern needed for scan-before-push.

### Job 5 — `updatek8s` (needs: build, docker, code-quality)

```yaml
updatek8s:
  runs-on: ubuntu-latest
  needs: [build, docker, code-quality]
  if: needs.docker.result == 'success'
      && github.event_name == 'pull_request'
      && github.event.pull_request.head.repo.full_name == github.repository
  steps:
    - Checkout code (with write token + PR branch ref)
      with:
        token: ${{ secrets.GITHUB_TOKEN }}
        ref: ${{ github.head_ref }}

    - Update image tag in k8s deployment manifest
      run: |
        FILE="kubernetes/api-gateway/deploy.yaml"
        sed -i "s|image: .*api-gateway:.*|image: ${{ env.DOCKER_IMAGE }}:${{ github.run_id }}|g" "$FILE"

    - Commit and push changes
      run: |
        git config --global user.email "teju.654@gmail.com"
        git config --global user.name "tejupagudala"
        git add kubernetes/api-gateway/deploy.yaml
        git commit -m "[CI]: Update api-gateway image tag to ${{ github.run_id }}" || echo "No changes to commit"
        git push origin HEAD:${{ github.head_ref }}
```

**The `|| echo "No changes to commit"` is defensive idempotency.** Re-runs of the workflow on the same commit don't fail.

---

<a name="foundation-concepts"></a>
## 5. Foundation Concepts

### JaCoCo (Java Code Coverage)

- Maven plugin
- Instruments compiled bytecode (injects counters into classes)
- Runs during `verify` phase
- Tracks lines, branches, methods exercised by tests
- Produces `target/site/jacoco/jacoco.xml`
- SonarCloud reads this XML for the quality gate

**Typical numbers:** 70-80% line coverage is "good," 90%+ is "great." Branch coverage harder — 50-70% normal.

### SonarCloud vs SonarQube

Both made by **SonarSource**, same scanning engine, different deployment:

| | SonarQube | SonarCloud |
|---|---|---|
| **Deployment** | Self-hosted | SaaS (sonarcloud.io) |
| **Cost** | Free CE, paid editions | Free for public, paid for private |
| **Organization concept** | No | Yes (your `SONAR_ORG` env) |
| **Compliance** | Data stays in your network | Data goes to SonarCloud |

**Your project uses SonarCloud** (proof: you have `SONAR_ORG` env var; only SonarCloud has organizations).

### Self-Hosted SonarQube in Private VPC

Enterprise architecture for "source code never leaves VPC":

- SonarQube Server on EKS pod (internal ALB, private subnet)
- RDS PostgreSQL backend (private subnet, multi-AZ, encrypted)
- DB password in AWS Secrets Manager, accessed via IRSA
- CI runner inside the VPC
- No NAT egress for source code
- DNS via Route 53 private hosted zone (`sonar.corp.internal`)
- ACM private CA cert for TLS

### Blocking Gate vs Info-Only

```yaml
sonar:sonar                                    # Info-only — uploads to dashboard, CI passes regardless
sonar:sonar -Dsonar.qualitygate.wait=true      # Blocking — CI fails on gate failure, merge blocked
```

**`wait=true` makes the quality gate enforceable, not advisory.** Without it, results are dashboard wallpaper.

### CVE & CVSS

- **CVE** = Common Vulnerabilities and Exposures — public ID for a known software flaw (e.g., `CVE-2021-44228`)
- Maintained by **MITRE**, funded by **US CISA**
- **CVSS** = Common Vulnerability Scoring System — severity 0.0-10.0

| CVSS | Severity |
|---|---|
| 0.0-3.9 | LOW |
| 4.0-6.9 | MEDIUM |
| 7.0-8.9 | HIGH |
| 9.0-10.0 | CRITICAL |

**Famous CVEs to namedrop:**
- **Log4Shell** — CVE-2021-44228 — log4j2 RCE, CVSS 10.0, Dec 2021
- **Spring4Shell** — CVE-2022-22965 — Spring Framework RCE
- **runc container escape** — CVE-2024-21626 — early 2024 K8s/Docker
- **Heartbleed** — CVE-2014-0160 — OpenSSL

### Maven Multi-Module + `-pl` / `-am`

- `-pl spring-petclinic-api-gateway` = **--projects** = "build ONLY this module"
- `-am` = **--also-make** = "also build dependencies this module needs"
- Together = "build the smallest valid subgraph"

**Without flags:** ~5 min to build all 6 services
**With flags:** ~1 min to build just api-gateway + deps
**Speedup: 5x**

### Java 17 vs Temurin

"Java 17" is the **spec**. Distributions:

| Distribution | Vendor | Cost |
|---|---|---|
| Oracle JDK | Oracle | PAID for production |
| **Temurin** | Eclipse Foundation | FREE, TCK-certified ← industry default |
| Corretto | Amazon | Free, AWS-optimized |
| Zulu | Azul | Free CE, paid enterprise |

**Saying "Temurin" signals Java licensing awareness.** Most juniors say "Java 17" and don't realize Oracle JDK requires a paid license.

### GitHub Runners

Two types:

| | GitHub-hosted | Self-hosted |
|---|---|---|
| Provisioning | GitHub provisions fresh VM | You run an EC2/VM and register it |
| State | Ephemeral (destroyed after job) | Persistent |
| Cost | Free for public repos | EC2 cost (~$15/mo for t3.small) |
| Network access | Public internet only | Anywhere |
| Security | GitHub's responsibility | Yours |

Your `ci.yaml` uses `runs-on: ubuntu-latest` (GitHub-hosted). Your **Phase 3** self-hosted runner is for reaching the private EKS cluster.

### Idempotency

**Idempotent** = same result whether run once or 100 times.

In your pipeline:
- `sed` step: ✅ idempotent (re-runs change nothing)
- `git push`: ✅ idempotent (already pushed = no-op)
- `git commit`: ❌ NOT idempotent (fails on "nothing to commit")

The `|| echo "No changes to commit"` makes git commit behave idempotently.

### The `||` Operator

```bash
command1 || command2    # Run command2 ONLY if command1 FAILS
```

| Operator | Meaning |
|---|---|
| `&&` | Run next ONLY if previous succeeded |
| `\|\|` | Run next ONLY if previous failed |
| `;` | Always run next |
| `\|` | Pipe stdout to next command |

### Why NEVER `:latest` in K8s Manifests

Four breakdowns:

1. **No rollback** — can't pin to "yesterday's image"
2. **No audit trail** — `kubectl describe` shows `:latest`, not the actual build
3. **Pull semantics** — `imagePullPolicy: IfNotPresent` won't re-pull existing tags
4. **Deployment change detection** — pod spec hash doesn't change, K8s thinks nothing's new

**Real-world scenario:** Production breaks at 2 AM. With `:latest`, `kubectl rollout undo` doesn't help — rolls back TO `:latest` (same image). 30-minute outage. With immutable `run_id` tags, `git revert` fixes it in 2 minutes.

### When `:latest` IS OK

**Local dev only:**
- Quick smoke test on laptop
- Demos
- docker-compose
- README documentation

**Never in any Kubernetes cluster** (dev, staging, prod).

---

<a name="hostile-qa"></a>
## 6. 5 Hostile Interview Q&A (Drilled)

### Q1: "Walk me through your CI/CD pipeline end to end."
**Score: 8.5/10**

**Ideal answer (~95 seconds spoken):**

> *"My CI pipeline lives in `.github/workflows/ci.yaml`. It triggers on pull requests targeting main, paths-filtered to `app/`, `kubernetes/api-gateway/`, `terraform/`, or the workflow file itself.*
>
> *Five jobs run in this order: First, **build** — Java 17 Temurin, Maven multi-module with `-pl spring-petclinic-api-gateway -am`, skip tests for fast failure, then run tests separately. In parallel, **code-quality** runs SonarCloud with JaCoCo coverage, gated by `qualitygate.wait=true` — the workflow blocks until SonarCloud returns pass/fail, so it's a real gate, not advisory.*
>
> *After both succeed, **security-scan** runs Trivy in three modes — filesystem, Kubernetes config, Terraform config — all set to exit-1 on HIGH or CRITICAL CVEs, CVSS ≥ 7. Then **docker** — buildx, login, build WITHOUT pushing, Trivy image scan, only THEN push with two tags: `github.run_id` for immutability and `latest` for convenience.*
>
> *Finally, **updatek8s** sed-replaces the image tag in the Kubernetes manifest and commits to the PR branch as a bot user. Once the PR merges to main, Argo CD picks up the new manifest and reconciles the cluster — that's the GitOps separation of concerns: CI builds and updates git, CD deploys from git. The whole pipeline takes about 4-5 minutes."*

**What hits the 8.5/10 bar:**
- ✅ Hit all 6 beats (trigger, build, quality, security, docker, deploy)
- ✅ Senior signals: `qualitygate.wait=true`, CVSS ≥ 7, scan-before-push, GitOps invariant, fork protection, bot user
- ✅ Specific timing ("4-5 minutes")
- ✅ Named "GitOps separation of concerns"

---

### Q2: "Why update the K8s manifest from CI instead of running kubectl apply directly?"
**Score: 9/10 (after re-attempt)**

**Ideal answer (~80 seconds spoken):**

> *"If CI ran `kubectl apply` directly, CI would need cluster credentials — and that creates three problems. First, security: credentials in CI mean if my CI is compromised, the attacker controls the cluster. Second, state drift: someone could `kubectl edit` something manually and the cluster would diverge from git, with no way to know what's actually running. Third, disaster recovery: I couldn't rebuild the cluster from git if git wasn't actually driving the cluster state.*
>
> *Instead, I use the GitOps pattern — separation of concerns: CI builds and updates git; CD deploys from git. My CI updates the image tag in the Kubernetes manifest and commits it. Argo CD, running inside the cluster, pulls from git and reconciles the cluster to match. The cluster has credentials to Argo CD's identity; my CI has zero cluster credentials.*
>
> *The operational payoff is huge: rollback becomes `git revert` instead of manually figuring out the previous image tag. Audit is `git log` — every deployment is a commit with an author. Argo CD's UI shows drift in real time — if anything in the cluster doesn't match git, I see it immediately. And if I add a second cluster tomorrow, I just point another Argo CD at the same git repo — same source of truth, different reconcilers."*

**Secret weapon phrases:**
- "CI builds and updates git; CD deploys from git" — GitOps in 10 words
- "Rollback becomes `git revert`"
- "Push-based vs pull-based deployment"
- "Argo CD detects drift in real time"
- "Same git, different reconcilers"

---

### Q3: "Why scan the Docker image BEFORE push instead of after?"
**Score: 7.5/10**

**Ideal answer (~75 seconds spoken):**

> *"Scan-after-push is the lazy default — the image is already in the registry before you know it's bad. Anyone with pull access can grab it, K8s pods can deploy it, an attacker analyzing the registry can find the CVE. The registry is a trust boundary; once you've crossed it, you've lost control.*
>
> *Scan-before-push reverses that. My pipeline does `build` with `push: false, load: true` — the image goes into the runner's local Docker daemon, never DockerHub. Trivy scans it there. If it finds HIGH or CRITICAL CVEs with available fixes, exit-1 fails the job. Only if the scan passes does the next step run `push: true`. A bad image never reaches the registry, so nothing in the cluster can pull it.*
>
> *This also gives me defense in depth alongside the FS scan. FS scan catches source-level dependencies in my pom.xml. Image scan catches what's actually baked in — base image vulns from `eclipse-temurin:17`, transitive packages, OS-level libs. A clean FS scan doesn't mean a clean image. Imagine my base image bundled Log4Shell — CVE-2021-44228, CVSS 10.0. FS scan would never see it because it's not in my source. Image scan catches it before publish.*
>
> *This is what NIST SSDF and CISA recommend for supply chain security — gate the registry, not just the dashboard."*

**Power phrases:**
- "The registry is a trust boundary"
- "Defense in depth"
- "Different attack surfaces" (source vs baked-in)
- Log4Shell as concrete example
- NIST SSDF + CISA citations

---

### Q4: "Why github.run_id as image tag — why not git SHA?"
**Score: 7/10**

**Ideal answer (~60 seconds spoken):**

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

---

### Q5: "What happens if your updatek8s commit fails — does CI mark itself green or red?"
**Score: 6.5/10**

**Ideal answer (~75 seconds spoken):**

> *"It depends on which step failed. If `git push` fails — auth error, network issue, branch protection — the job fails, the workflow is red, the PR check is red, and branch protection blocks the merge.*
>
> *State at that point: the Docker image IS in DockerHub (the docker job succeeded before updatek8s ran), but the K8s manifest in git was NOT updated. That's a partial-success state.*
>
> *Recovery is simple because the pipeline is designed to be idempotent: I fix the issue — refresh the GITHUB_TOKEN, fix branch protection, whatever — and re-run the workflow. The `sed` step is idempotent so it doesn't matter if it runs again. The `git commit` step has a `|| echo 'No changes to commit'` guard, so if it re-runs without changes it still passes. The image push just overwrites the immutable `run_id` tag with the same image. Once the workflow goes green, the manifest is updated, the PR can be merged, and Argo CD picks up the change.*
>
> *Importantly, I have an `if: needs.docker.result == 'success'` guard on the updatek8s job — that prevents the WORST partial state where you'd update the manifest pointing to an image that doesn't exist in the registry. Updatek8s only runs if the image is confirmed pushed."*

**Critical correction:** DO NOT merge the PR manually if updatek8s failed. Branch protection should block it; merging without manifest update silently ships nothing.

---

<a name="followup-qa"></a>
## 7. 8 Follow-Up Q&A (Quick-Fills)

### F1: "What happens AFTER the PR merges to main? How does the image actually reach the cluster?"

> *"My CI workflow runs on `pull_request` events — it stops at updating the manifest in the PR branch. After I merge the PR, no CI workflow re-runs. The deployment is then driven by Argo CD, which is running inside my EKS cluster and watching the main branch. When Argo CD's reconciliation loop sees the manifest on main has changed (new image tag), it pulls the new manifest and applies it. That's the GitOps pull-based model — git is the trigger, not CI."*

### F2: "What's the Maven `verify` lifecycle phase? Why does it matter?"

> *"Maven runs through phases in order: `validate → compile → test → package → verify → install → deploy`. The `verify` phase is where JaCoCo's `report` goal hooks in — it generates `jacoco.xml`. SonarCloud needs that XML to compute coverage in the quality gate. That's why my CI runs `mvn verify sonar:sonar` — `verify` produces the report, then `sonar:sonar` uploads it. Without `verify`, JaCoCo wouldn't generate the report, and SonarCloud would show 0% coverage."*

### F3: "What happens if two developers open PRs at the same time?"

> *"Each PR triggers its own independent workflow run on its own branch. They run in parallel on separate GitHub-hosted runners — no conflict during execution. The conflict happens when they both try to merge to main — whoever merges second hits a merge conflict on `kubernetes/api-gateway/deploy.yaml` because both PRs updated the image tag. The second developer rebases and resolves manually. For high-traffic teams, I'd add `concurrency: { group: api-gateway-${{ github.head_ref }}, cancel-in-progress: true }` to the workflow to prevent stale runs from the same PR."*

### F4: "What's Docker Buildx and why use it instead of regular `docker build`?"

> *"Buildx is Docker's modern build engine based on BuildKit. It gives me three things regular `docker build` doesn't: (1) multi-platform builds — same command for amd64 and arm64; (2) better caching — granular layer cache that respects multi-stage builds; (3) the `load: true, push: false` pattern I rely on to scan images before push. I declare it once with `docker/setup-buildx-action@v3` and `docker/build-push-action@v6` uses it automatically."*

### F5: "How does `cache: maven` work in `actions/setup-java@v4`?"

> *"GitHub Actions has a built-in cache mechanism. When `cache: maven` is set, the action hashes my `pom.xml` files, downloads `~/.m2/repository` from cache if a matching key exists, runs my build, and saves the updated repo back to cache at the end. On the next run with unchanged `pom.xml`, Maven finds all dependencies locally — first build downloads 100+ MB of deps, subsequent builds skip that. Cuts build time from ~5 min to ~1.5 min."*

### F6: "How are GitHub Secrets injected? Are they ever logged?"

> *"Secrets are encrypted at rest by GitHub using libsodium sealed boxes. At runtime, GitHub injects them as environment variables only into steps that explicitly reference them via `${{ secrets.X }}`. GitHub also automatically redacts secret values from logs — if I accidentally `echo` a secret, the log shows `***`. The exception is if I transform a secret (base64 encode it, etc.) — the transformed version isn't auto-redacted, which is a common leak vector."*

### F7: "What if SonarCloud is down — does your CI break?"

> *"Yes — `sonar.qualitygate.wait=true` makes the workflow block until SonarCloud responds. If SonarCloud is down, the job times out or fails. That's actually a feature, not a bug — I'd rather have a temporary CI block than silently bypass the quality gate. For higher-availability needs, I could add `continue-on-error: true` to make it advisory during outages, but that defeats the gate's purpose. Right answer for production: monitor SonarCloud status, accept brief CI pauses during their incidents."*

### F8: "Walk me through your Dockerfile."

> *"It's a two-stage build using Eclipse Temurin 17 as both stages. Stage 1 is the builder — it takes my Spring Boot JAR and uses `layertools extract` to split it into 4 layers: dependencies (80% that rarely changes), spring-boot-loader, snapshot-dependencies, and the application code. Stage 2 is the runtime — it copies each of those 4 layers as separate `COPY` instructions, so Docker can cache them independently. When I change app code, only the last layer (~2MB) rebuilds instead of the entire 150MB fat JAR. Entrypoint is `java org.springframework.boot.loader.launch.JarLauncher`."*

---

<a name="power-phrases"></a>
## 8. Power Phrases & Secret Weapons

Drop these phrases in interviews — each is a senior-coded signal:

### GitOps / Architecture
- ✨ **"CI builds and updates git; CD deploys from git"** — GitOps in 10 words
- ✨ **"Git is the source of truth; the cluster is a downstream artifact"**
- ✨ **"Separation of concerns"**
- ✨ **"Push-based vs pull-based deployment"**
- ✨ **"Same git, different reconcilers"** (multi-cluster)
- ✨ **"Rollback becomes `git revert`"**

### Security
- ✨ **"The registry is a trust boundary"**
- ✨ **"Defense in depth"**
- ✨ **"Scan-before-push is the gate; scan-after-push is visibility"**
- ✨ **"NIST SSDF / CISA recommended pattern"**
- ✨ **"Supply chain security"**
- ✨ **"Pwn request" attack vector** (forked PRs exploiting tokens)

### CI/CD Mechanics
- ✨ **"Idempotent recovery"** — design principle
- ✨ **"Blocking gate vs advisory"**
- ✨ **"Quality gate `wait=true` makes the gate enforceable, not decorative"**
- ✨ **"Paths-filter cuts unnecessary builds by 40-60%"**

### Image / Tagging
- ✨ **"Run_id is the canonical link between an image and its provenance"**
- ✨ **"Content-addressable identity"**
- ✨ **"`:latest` breaks rollback, audit, pull semantics, and deployment change detection"**

### Operational Maturity
- ✨ **"One click brings the whole platform up; one click tears it down"** (your bootstrap brag)
- ✨ **"YAGNI principle — proved the pattern in one service before templatizing"**

---

<a name="common-mistakes"></a>
## 9. Common Mistakes to Avoid

| Mistake | Why it hurts |
|---|---|
| Saying "**SonarQube**" when you mean **SonarCloud** | Precision matters; interviewer asks "where's your instance hosted?" → trap |
| Saying "**Travis**" when you mean **Trivy** | Travis CI is a different product entirely |
| Saying "**Sprint**" when you mean **Spring Boot** | Voice-to-text artifact you must enunciate around |
| Saying "**RDS becomes IDE**" (verbal slip) | Database product confusion |
| Saying "**:latest**" anywhere near K8s manifests | Anti-pattern interviewers hate |
| Stating "**I'm not sure**" at start of an answer | Confidence killer; lead with best guess |
| Manually merging a red PR | Branch protection should block it; merging silently ships nothing |
| Claiming CI/CD did **kubectl apply** directly | Wrong — CI updates git, Argo CD deploys |
| Saying you built CI for **all 6 services** | Lie — you built for api-gateway only (defensible reasons exist) |
| Inventing fake metrics ("reduced downtime by 40%") | Background check will catch fabrication; honest framing wins |

---

<a name="cheat-card"></a>
## 10. Cheat Card (One-Page Summary)

### Phase 1 Architecture
```
GitHub repo
    │
    │ on: pull_request to main, paths-filtered
    ▼
GitHub Actions (5 jobs):
  build → code-quality → security-scan → docker → updatek8s
                                                       │
                                                       │ commits manifest tag bump
                                                       ▼
                                                 PR branch
                                                       │
                                                       │ (PR merged to main)
                                                       ▼
                                                Main branch
                                                       │
                                                       │ Argo CD polls every 3 min
                                                       ▼
                                                  EKS cluster
                                                  (api-gateway deployed)
```

### Tech Stack
| Layer | Choice |
|---|---|
| Application | Spring Boot 4.0.1, Spring Cloud 2025.1.0 |
| JVM | Java 17 (Eclipse Temurin) |
| Build | Maven multi-module (`-pl -am`) |
| Container | Multi-stage Dockerfile + layertools |
| Registry | DockerHub (two tags: run_id + latest) |
| CI Runner | GitHub-hosted (`ubuntu-latest`) |
| Quality Gate | SonarCloud + JaCoCo (blocking via `wait=true`) |
| Security | Trivy 3-mode (FS + K8s + Terraform) + image scan-before-push |
| Deployment | GitOps via Argo CD (Phase 7) |

### Numbers to Remember
- CI pipeline duration: **4-5 minutes**
- Paths-filter savings: **40-60% fewer unnecessary builds**
- Maven cache speedup: **5 min → 1.5 min** subsequent builds
- Layertools rebuild size: **150 MB → 2 MB** code-change rebuilds
- CVSS threshold for build fail: **≥ 7.0** (HIGH/CRITICAL)

### Interview Q Score Targets
| Question Type | Target |
|---|---|
| Walk me through CI/CD | 8.5+ |
| Why GitOps? | 9+ |
| Why scan before push? | 8+ |
| Why run_id tags? | 8+ |
| Failure modes? | 8+ |

### Universal Q&A Framework (when stumped)
1. **State the choice you made** (1 sentence)
2. **3 reasons why** (the reasoning)
3. **What you didn't do and why** (the tradeoffs)
4. **Senior-coded phrase** (one secret weapon)
5. **Close with operational benefit** (the why-it-matters)

---

## Phase 1 — COMPLETE ✅

**Average score across 5 questions: 7.7/10 — interview-viable at the $120K-165K band.**

Next: [Phase 2 — Cost Discipline & Quality Gates](phase-2-reference.md) (when ready)
