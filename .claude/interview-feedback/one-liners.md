# Interview One-Liners — Cheat Card

Interview-grade one-liners. Drop them verbatim. Memorize for cramming before any interview.

**How to use:**
- Before interview: Read top to bottom (~10 min)
- During interview: Drop the matching one-liner when the topic comes up
- After interview: Add new questions that came up
- Weekly: Re-read to stay fresh

---

## 📑 Table of Contents

- [Phase 1 — CI/CD Foundation](#phase-1--cicd-foundation)
- [Phase 2 — Cost Discipline](#phase-2--cost-discipline)
- [Phase 2 — Security Hardening](#phase-2--security-hardening)
- [Phase 2 — Least-Privilege IAM](#phase-2--least-privilege-iam)
- [Phase 6 — RDS + Secrets Manager](#phase-6--rds--secrets-manager-simple-language)
- [Phase 7 — AIOps Foundation: EKS Access + CloudWatch](#phase-7--aiops-foundation-eks-access--cloudwatch-simple-language)
- [Phase 8 — AIOps Service + Streamlit UI](#phase-8--aiops-service--streamlit-ui-simple-language)
- [GitHub Actions Mechanics](#github-actions-mechanics)
- [The Senior "Power Phrases" (Drop Anywhere)](#power-phrases)

---

## Phase 1 — CI/CD Foundation

### The WHY of CI/CD (manual deploys vs GitOps)
> *"Manual deploys are slow, error-prone, and the cluster diverges from source control with no audit trail. GitOps flips this — git becomes the source of truth, Argo CD reconciles the cluster to match, and the cluster becomes a downstream artifact instead of a piece of mutable infrastructure people manually touch."*

### Repo structure + Spring Petclinic context
> *"My project forks the Spring Petclinic Microservices reference architecture — six Spring Boot services. The repo is organized into four clean top-level directories: `app/`, `terraform/`, `kubernetes/`, and `.github/workflows/`. That separation signals architectural maturity — most juniors mix Terraform into the app folder."*

### Walk me through the CI/CD pipeline
> *"My pipeline has five jobs in order: `build` (Maven multi-module), `code-quality` (SonarCloud + JaCoCo, blocking gate), `security-scan` (Trivy in three modes), `docker` (build → scan-before-push → push with two tags), and `updatek8s` (sed-replace the image tag, commit to PR branch as a bot user). The whole thing runs in 4-5 minutes."*

### Multi-stage Dockerfile + layertools
> *"My Dockerfile is a two-stage build. The builder uses Spring Boot's `layertools extract` to split the fat JAR into four layers — dependencies, spring-boot-loader, snapshot-dependencies, and application code. The runtime stage copies each as a separate `COPY` instruction. Result: code-change rebuilds drop from 150 MB to 2 MB because Docker only rebuilds the application layer."*

### Maven multi-module + -pl -am flags
> *"`-pl spring-petclinic-api-gateway` builds only that module; `-am` (also-make) adds its dependencies. Together they let me build just api-gateway plus what it needs in about a minute, instead of rebuilding all six services for five minutes — a 5x CI speedup on monorepos."*

### Java 17 vs Temurin distribution
> *"Java 17 is the spec; Temurin is the free, Eclipse-Foundation distribution. I picked Temurin because Oracle JDK requires a paid license for production use, and Temurin is the industry default for new Java workloads since 2021. It's also TCK-certified and natively supported by `actions/setup-java@v4`."*

### JaCoCo + SonarCloud (blocking gate)
> *"JaCoCo instruments bytecode to measure coverage during the Maven `verify` phase and emits `jacoco.xml`. SonarCloud reads that XML to compute the coverage portion of the quality gate. The `sonar.qualitygate.wait=true` flag makes the gate truly blocking — the workflow halts until pass or fail returns, instead of letting results go to a dashboard people forget to check."*

### SonarCloud vs SonarQube + private-VPC self-hosting
> *"SonarCloud is the SaaS at sonarcloud.io — zero ops, perfect for public repos and small teams. SonarQube is the self-hosted alternative for enterprises where source code can't leave the network. In a regulated environment, I'd deploy SonarQube on EKS with an internal ALB, RDS Postgres backed by Secrets Manager via IRSA, and CI runners inside the VPC — source code never crosses the public internet."*

### CVE + CVSS scoring
> *"CVE is the public identifier for a known vulnerability, maintained by MITRE. CVSS is the 0-10 severity score. My Trivy gate fails the build on HIGH and CRITICAL — CVSS 7.0 and above — with `ignore-unfixed: true` because blocking on unfixed CVEs is a dead end for the developer."*

### Trivy 3-mode scanning + scan-before-push
> *"I run Trivy in three modes: filesystem scan on `app/` for source dependencies, config scan on `kubernetes/api-gateway/` for K8s misconfigurations, and config scan on `terraform/` for IaC misconfigurations. The Docker image gets a fourth Trivy scan — built locally with `load: true, push: false`, scanned, and only pushed if clean. The registry is a trust boundary; a CVE-laden image never crosses it."*

### Docker Buildx + DockerHub mechanics
> *"Buildx is Docker's modern BuildKit-based engine. It gives me multi-platform builds, granular layer caching, and the critical `load: true, push: false` pattern I need to scan images before push. I authenticate to DockerHub with a username plus a scoped access token from GitHub Secrets, not a password."*

### GitOps philosophy + Argo CD reconciliation
> *"CI builds and updates git; CD deploys from git. My CI updates the image tag in the Kubernetes manifest and commits it. Argo CD, running inside the cluster, polls the main branch every three minutes and reconciles the cluster to match. The cluster has Argo CD's identity; my CI has zero cluster credentials. Rollback becomes `git revert`; audit becomes `git log`."*

### Two-tag strategy (run_id + latest)
> *"Every image gets two tags: `github.run_id` for immutability and `:latest` for local-dev convenience. Run_id maps 1:1 to a CI run, so I can trace any deployed image back to the exact tests, scans, and commit. `:latest` only lives on DockerHub — it never goes near a Kubernetes manifest."*

### Why never :latest in K8s manifests
> *"`:latest` breaks four things in K8s: rollback (can't pin to a previous image), audit (`kubectl describe` shows the tag, not the build), pull semantics (`imagePullPolicy: IfNotPresent` won't re-pull existing tags), and deployment change detection (pod spec hash doesn't change). Immutable tags solve all four with zero downside."*

### The || operator + idempotency
> *"`||` is shell's logical OR — `command1 || command2` runs command2 only if command1 fails. My `git commit ... || echo 'No changes to commit'` swallows the 'nothing to commit' failure that would otherwise break workflow re-runs on the same commit. It turns a non-idempotent step into a safe-to-retry one."*

### The 3-guard if: condition
> *"My updatek8s job has three guards: `docker.result == 'success'` prevents updating the manifest to a non-existent image; `event_name == 'pull_request'` prevents crashing on missing variables for non-PR triggers; and `head.repo.full_name == github.repository` blocks forked PRs from running the commit-back step — defending against the 'pwn request' attack vector where a malicious fork modifies the workflow to steal the bot token."*

### Failure modes + partial-state recovery
> *"If updatek8s fails after docker push succeeded, the image is in DockerHub but the manifest in git isn't updated — a partial-success state. The workflow goes red, the PR check goes red, branch protection blocks the merge. Recovery is idempotent: fix the issue, click 're-run failed jobs', every step is safe to repeat. I never merge a red PR — that ships the old code while the new image sits orphaned in the registry."*

### What happens after PR merges to main
> *"My CI runs only on `pull_request` events — it stops at updating the manifest in the PR branch. After I merge to main, no CI re-runs. Argo CD, running inside the cluster, watches main, sees the new manifest, pulls it, and applies it. Git is the trigger, not CI — that's the pull-based GitOps model."*

### Concurrent PR conflicts
> *"Two PRs run in parallel on separate runners — no conflict during execution. The conflict happens at merge time: both PRs updated the same `deploy.yaml`, so the second merge gets a merge conflict. For high-throughput teams, I'd add `concurrency: { group: api-gateway-${{ github.head_ref }}, cancel-in-progress: true }` to kill stale runs from the same PR."*

### actions/setup-java@v4 caching
> *"The `cache: maven` option hashes my `pom.xml` files, downloads `~/.m2/repository` from GitHub Cache if a matching key exists, runs my build, and saves the updated repo back at the end. First build downloads 100+ MB of dependencies; subsequent builds skip that entirely. Cuts build time from about 5 minutes to 1.5 minutes."*

### GitHub Secrets injection + log redaction
> *"Secrets are encrypted at rest by GitHub using libsodium sealed boxes. At runtime they're injected as environment variables only into steps that reference them via `${{ secrets.X }}`. GitHub auto-redacts secret values from logs — if I accidentally `echo` a secret, the log shows `***`. The leak vector to watch is transforms: if I base64-encode a secret, the transformed version isn't auto-redacted."*

### contents: write permission — hardening
> *"At the workflow level `contents: write` is coarse. The tighter version is to default the workflow to `contents: read` and scope `write` only to the `updatek8s` job. Beyond that, the truly senior move is to remove CI's write access entirely using Argo CD Image Updater — it watches the registry from inside the cluster and updates manifests itself, so CI has zero git write permissions."*

---

## Phase 2 — Cost Discipline

### The 4-layer cost model (overarching framing)
> *"My cost discipline runs across four layers — two reactive, two proactive. Spot t3.small for cheap compute, scheduled cron scaling for off-hours waste, daily cost report as a CI gate for real-time threshold violations, AWS Budgets plus Cost Anomaly Detection for proactive governance. Together they keep my AWS bill under twenty dollars a month while running a production-grade environment."*

### The 3-layer cost defense matrix (defense-in-depth)
> *"AWS Budgets catches threshold violations. Daily cost report catches real-time stealth cost drivers like NAT Gateway and ELB. Cost Anomaly Detector catches ML pattern deviations below my budget threshold. Three different mechanisms for three different failure modes — not redundant, complementary."*

### Spot instances
> *"My EKS nodegroup uses spot t3.small instances — roughly 70% cheaper than on-demand. For a portfolio project, momentary interruptions are acceptable. For production with stricter SLAs, I'd run mixed instance types and pools to spread reclaim risk."*

### Scheduled nodegroup scaling
> *"My `non-prod-stop.yaml` runs at 11 PM Chicago via cron and scales the EKS nodegroup to zero. `non-prod-start.yaml` scales it back to two at 8 AM. That's roughly 62% compute savings on top of spot, while still keeping the cluster usable during my work hours."*

### Daily cost report workflow
> *"`cost-report-daily.yaml` calls AWS Cost Explorer every morning, groups yesterday's spend by service and usage-type, flags risky lines like NatGateway-Hours and LoadBalancerUsage, emails me via SNS, and fails the workflow if cost exceeds my daily limit. Cost becomes a CI gate, not a dashboard people forget to check."*

### AWS Cost Explorer API
> *"AWS Cost Explorer is the API I hit for cost data — `ce:GetCostAndUsage` returns spending grouped by SERVICE, USAGE_TYPE, LINKED_ACCOUNT, or custom dimensions. It doesn't support resource-level permissions in IAM — requires `*` — which is a documented AWS API limitation."*

### AWS Budgets multi-tier alerts
> *"I run a monthly total budget plus four per-service budgets — EKS, EC2-Other, VPC, ELB — each with three notification thresholds: 50% actual, 80% forecasted, 100% actual. Graduated warning catches runaway spend before the bill arrives."*

### KMS-encrypted SNS for cost alerts
> *"My SNS topic for cost alerts uses a customer-managed KMS key with rotation enabled. Cost data is sensitive — encrypting at rest is AWS best practice and a SOC2/PCI requirement. The KMS key policy includes an `aws:SourceAccount` condition to defend against the confused deputy attack."*

### SNS fan-out pattern
> *"SNS gives me pub/sub fan-out — one topic, multiple subscribers. Today it's email; tomorrow I could add Slack, PagerDuty, Lambda, or SQS without touching the publishers. Email subscriptions require manual confirmation, so the topic can't accidentally spam someone."*

### AWS Cost Anomaly Detection
> *"On top of the threshold-based budgets, I have a dimensional Cost Anomaly Detector monitoring SERVICE-level spend daily. AWS-managed ML model trained on 90 days of my account's spend history. Catches sub-budget patterns Budgets miss — like a forgotten resource burning $3/day below my $20 threshold but deviating from my baseline."*

### `cost_guardrails.tf` in 60 seconds
> *"`cost_guardrails.tf` builds my entire cost governance stack in about 420 lines — five AWS Budgets with three notification tiers, a KMS-encrypted SNS topic for alerts, AWS Cost Anomaly Detector with dimensional ML monitoring, an OIDC trust setup for GitHub Actions, and a least-privilege IAM role for cost-ops workflows with six statements scoped by ARN, tag conditions, or documented exceptions. Everything parameterized — partition, account ID, cluster name, email — nothing hardcoded."*

---

## Phase 2 — Security Hardening

### Pod Security Standards Restricted profile (framework name)
> *"My pods enforce the Pod Security Standards Restricted profile — the strictest of Kubernetes' three baseline tiers (Privileged, Baseline, Restricted). Maps to CIS Kubernetes Benchmark sections 5.1 through 5.7 — the standard security audit document for K8s."*

### Pod security context — full hardening
> *"My pods enforce six PSS Restricted settings: `runAsNonRoot: true`, `runAsUser: 1000`, `allowPrivilegeEscalation: false`, all Linux capabilities dropped, `readOnlyRootFilesystem: true`, and `seccompProfile: RuntimeDefault`. That's the full CIS Kubernetes Benchmark hardening checklist."*

### runAsNonRoot: true
> *"`runAsNonRoot: true` makes Kubernetes refuse to start the container if it tries to run as UID 0. Defense in depth — even if the image accidentally specifies root, the kubelet blocks it."*

### runAsUser + runAsGroup + fsGroup (identity, not permissions)
> *"`runAsUser: 1000` sets the process UID. `runAsGroup: 1000` sets the primary group GID. `fsGroup: 1000` sets the GID applied to mounted volumes so the non-root user can read/write them. These set IDENTITY, not permissions — the difference matters because they're frequently confused."*

### allowPrivilegeEscalation: false
> *"`allowPrivilegeEscalation: false` blocks setuid binaries and `sudo` from gaining root. Even if an attacker compromises my JVM, they can't escalate to root inside the container."*

### readOnlyRootFilesystem: true
> *"`readOnlyRootFilesystem: true` mounts the container's root filesystem read-only. Attackers who escape the JVM can't drop binaries, modify configs, or persist anything. Writable directories like `/tmp` are emptyDir volumes mounted separately."*

### capabilities.drop: [ALL]
> *"Dropping ALL Linux capabilities removes kernel-level privileged operations like `NET_ADMIN` (network manipulation), `SYS_PTRACE` (process tracing), `SYS_MODULE` (loading kernel modules), `CHOWN` (changing file ownership). Spring Boot doesn't need any of them — I drop everything for full attack surface reduction."*

### seccompProfile: RuntimeDefault
> *"`seccompProfile: RuntimeDefault` applies Docker's curated syscall allowlist, blocking around 270 dangerous syscalls like `ptrace`, `mount`, `reboot`, and `keyctl`. seccomp is the Linux kernel's syscall filter — massive attack surface reduction with zero application impact."*

### CIS Kubernetes Benchmark
> *"The CIS Kubernetes Benchmark is the industry-standard security audit document for K8s. My pod security context implements sections 5.1 through 5.7 — non-root user, no privilege escalation, dropped capabilities, read-only filesystem, runtime default seccomp profile."*

### Real CVE example (runc container escape)
> *"runc CVE-2024-21626 was a container escape bug that let an attacker break out of the container onto the host filesystem. Even if my image scanning missed it, the pod security context would still constrain what the attacker could do — they'd land in a non-root, read-only, capability-stripped environment with seccomp filtering syscalls."*

### Pod security as backup gate
> *"Pod security context is the backup layer when image scanning misses something. CVEs in third-party libraries get discovered weeks or months after release. Hardened pod security buys me time — even if a CVE-laden image somehow ships, the attacker hits a wall."*

---

## Phase 2 — Least-Privilege IAM

### The 3 IAM patterns
> *"My cost-ops IAM role uses three patterns across six statements: ARN scoping where AWS supports resource-level permissions, tag-based conditions where ARNs aren't enough, and documented exceptions where AWS APIs force a `*`. Three patterns, no `*` left unjustified."*

### Attribute-Based Access Control (ABAC)
> *"ABAC means permissions controlled by tags, not just ARNs. My EC2 Start/Stop statement uses `Resource: instance/*` but a Condition block requires `ec2:ResourceTag/Role = "github-self-hosted-runner"`. AWS-recommended modern IAM pattern — more scalable than maintaining explicit ARN lists."*

### Tag-based IAM conditions
> *"My GitHub Actions role can stop and start EC2 instances, but only those tagged `Role=github-self-hosted-runner` via a Condition block. Even if the role were assumed maliciously, the blast radius is one EC2 instance — not my entire fleet."*

### ARN-scoped IAM statements
> *"Every statement in my cost-ops policy is scoped to specific ARNs — the five budget ARNs, the one SNS topic, the specific EKS cluster and nodegroup pattern. Where I had to use `*` (Cost Explorer doesn't support resource-level), I documented the exception with a `trivy:ignore: AVD-AWS-0057` comment and a justification."*

### trivy:ignore with reasoning
> *"When a Trivy rule has to be suppressed, I document WHY with an inline comment. `trivy:ignore: AVD-AWS-0057` plus 'Cost Explorer API requires *' creates an audit trail — a justified exception, not silent suppression. Auditors want documented reasoning, not blind overrides."*

### Trivy as continuous IAM check
> *"My entire IAM policy is enforced in CI by Trivy as a continuous check. If I ever accidentally loosen a permission, widen a resource scope, or remove a condition, the workflow fails. Security policy as code, with the gate built into the deployment pipeline."*

### Narrow EKS actions (what the role CANNOT do)
> *"My EKS scaling statement has only four actions: DescribeCluster, DescribeNodegroup, ListNodegroups, UpdateNodegroupConfig. The role CANNOT delete the cluster, create new nodegroups, modify cluster security groups, or rotate the API endpoint. Defining what a role can't do is as important as defining what it can."*

---

## Phase 3 — Private EKS + Self-Hosted Runner

### Why private EKS endpoint (Defense in Depth)
> *"I made the EKS API endpoint private-only as a defense-in-depth measure. Even with strict IAM, network controls catch what IAM doesn't — DDoS against the kube-apiserver, CVE exploitation like CVE-2018-1002105 which allowed unauthorized privilege escalation through the API server proxy, and stolen-credential abuse from outside the network. The Capital One 2019 breach is the canonical example — strict IAM didn't save them because credentials were used from the public internet after SSRF exfiltration."*

### Network + IAM as separate defense layers
> *"IAM defends against authorized misuse — what an authenticated user can do. Network controls defend against unauthorized reach — DDoS, CVE exploitation, reconnaissance, and stolen-credential abuse from outside the network. Removing either layer creates a single point of failure. Defense in depth requires both."*

### Self-hosted runner architecture
> *"My self-hosted runner is an EC2 instance inside my VPC — Amazon Linux 2023, IMDSv2 required, GP3 encrypted root volume, security group locked to my IP via GitHub Secrets, IAM role scoped to one SSM parameter, tagged with `Role=github-self-hosted-runner` for ABAC. It auto-registers with GitHub via user data script and runs as a long-lived service polling GitHub for jobs."*

### Why self-hosted instead of GitHub-hosted
> *"GitHub-hosted runners live on Azure's public internet — they can't reach my private EKS endpoint. My self-hosted runner lives inside my VPC, so it can reach the private endpoint. That's the entire reason for having a self-hosted runner — to bridge the public job-posting board (GitHub) with my private cluster (EKS)."*

### Long-lived runner vs ephemeral
> *"My runner is long-lived, not ephemeral — the EC2 stays running 24/7. Booting an EC2 per-job would waste 2 minutes per workflow run. After each job, the runner returns to idle waiting for the next one. For higher-security environments, ephemeral runners that terminate after each job exist, but they're more complex to set up and cost more in startup overhead."*

### IMDSv2 — defending against SSRF
> *"`http_tokens = required` forces IMDSv2-only mode. IMDSv1 was a simple GET request with no authentication — any process on the EC2 could query metadata and steal IAM credentials. IMDSv2 requires a session token first via PUT request with custom headers. Most SSRF attacks can't do PUT or custom headers, so IMDSv2 breaks the credential-theft chain. The Capital One 2019 breach would not have worked against IMDSv2."*

### EBS volume encryption with KMS
> *"My runner's root EBS volume is GP3 encrypted with KMS. AWS transparently encrypts blocks on write and decrypts on read — no application changes. Protects against snapshot exfiltration, stolen disks, and AWS internal access. Required by HIPAA, PCI-DSS, SOC2, GDPR — a compliance auditor will flag any unencrypted EBS volume immediately."*

### ABAC via Role tag
> *"My runner EC2 is tagged `Role=github-self-hosted-runner`. My Phase 2 cost-ops IAM policy uses this tag in a Condition block to scope EC2 Start/Stop permissions. Even though the policy's Resource is `instance/*`, the Condition narrows it to instances with this specific tag. Blast radius: one EC2 instance, not my entire fleet. That's Attribute-Based Access Control — permissions controlled by tags, not just ARNs."*

### 5-phase PAT lifecycle
> *"The PAT goes through five phases: creation on GitHub.com with `repo` scope, storage in SSM Parameter Store as SecureString encrypted at rest, retrieval by the EC2 via IAM role using IMDSv2-protected `ssm:GetParameter`, usage via the 2-step auth dance (PAT → registration token → register runner), and rotation by updating the Terraform variable and revoking the old PAT on GitHub."*

### 2-step auth dance (PAT → registration token)
> *"The runner does NOT use the PAT directly to register. It does a 2-step auth dance: use the PAT to call GitHub's API and get a short-lived registration token, then use THAT token to register the runner. The PAT is forgotten after this step — never lives on the runner's disk past initial registration. Blast radius reduction: if the runner is compromised post-registration, the attacker finds only an expired registration token, not the PAT."*

### SSM Parameter Store SecureString
> *"My runner's PAT lives in AWS SSM Parameter Store as a SecureString — encrypted at rest with KMS. The runner's IAM role has a single permission: `ssm:GetParameter` on this one specific parameter ARN. Least privilege at the secret level. Even if the runner is compromised, the attacker can only read this one parameter, not any other SSM secret in the account."*

### VPC interface endpoints — FinOps tradeoff
> *"I evaluated VPC interface endpoints for SSM to keep PAT-fetch traffic fully inside AWS's private network — three endpoints: `ssm` for the Parameter Store API, `ssmmessages` for the SSM agent channel, and `ec2messages` for command responses. The math: $8 each × 3 = $24/month, which exceeded my $20 monthly budget. Made a deliberate FinOps tradeoff: kept the runner in a public subnet with restricted egress. Commented out the endpoint code as the documented production upgrade path."*

### Cost-over-isolation tradeoff
> *"In a regulated production environment — banking, healthcare, defense — I'd budget for those VPC endpoints. Portfolio scope made the cost-over-isolation tradeoff acceptable, and the decision is documented. The pattern: know the right architecture, evaluate the cost, make the portfolio-appropriate compromise, document the tradeoff so future-me knows the upgrade path."*

### Helm-in-CI pain pattern
> *"Helm-in-CI is genuinely hard because Helm's state model — releases, secrets, lockfiles — assumes a long-running interactive session where a human can intervene. CI runs are atomic and short-lived; they must succeed or fail definitively. A hung Helm install equals a stuck CI job equals a blocked PR for hours. I had 8 commits between March 17-20 chasing this with four fixes: preflight `helm repo update`, `cancel-in-progress` concurrency control, stale release lockfile cleanup, and proper `--timeout` flags."*

### Argo CD Helm support (modern upgrade path)
> *"The modern alternative to Helm-in-CI is Argo CD's Helm support — it manages releases declaratively via GitOps. Create Argo CD Application CRDs for each chart, use the App-of-Apps pattern so one parent application discovers all child apps, and Argo CD reconciles releases automatically. CI becomes one line: `kubectl apply -f _root.yaml` once. Upgrades are just YAML edits in git — no CI Helm commands, no lockfile races, no hung installs."*

### GitHub PAT → GitHub Apps (modern upgrade path)
> *"The modern upgrade path beyond PATs is GitHub Apps — they use short-lived JWTs instead of long-lived PATs. Apps eliminate the long-lived secret problem entirely. For production scale, I'd migrate to GitHub Apps for runner registration."*

---

## Phase 4 — Bootstrap Stabilization Marathon

### The infra-bootstrap workflow (overall)
> *"My infra-bootstrap is 635 lines, runs in ~22 minutes — a one-click that takes the platform from `terraform destroy` to fully running Petclinic. It solves 5 problems simultaneously: sequencing, concurrency, idempotency, stale state recovery, auth expiration, and diagnostics on failure."*

### Bootstrap paradox (two-job architecture)
> *"My bootstrap has two jobs because of the bootstrap paradox. prepare-runner on GitHub-hosted wakes my self-hosted EC2 runner — the self-hosted runner can't boot itself. Then bootstrap runs on the self-hosted runner because it needs to reach the private EKS endpoint, which GitHub-hosted runners can't reach."*

### Targeted Terraform apply (chicken-and-egg fix)
> *"prepare-runner uses `terraform apply -target=` flags to create JUST the VPC and runner EC2, not the full stack. Full apply needs to run from inside the VPC, but the VPC and runner have to exist first. Targeted apply solves that ordering."*

### Workflow concurrency
> *"`concurrency: terraform-${{ github.repository }}` with `cancel-in-progress: false` serializes Terraform workflows. If a second bootstrap is triggered, it WAITS — doesn't cancel — because killing terraform mid-apply would corrupt the state file."*

### Cold-start vs warm-start
> *"Cold-start paths reveal bugs that warm-start hides — every chicken-and-egg surfaces at once because nothing exists yet. Bringing up an empty AWS account exposes assumptions I didn't even know I was making."*

### Idempotency framework (3 step types)
> *"My bootstrap is idempotent by design. Every step is one of three types: declarative apply (terraform/kubectl/helm), preflight-guarded change (status check before action), or read-only check (`kubectl wait`, diagnostic dumps). No unguarded one-time actions."*

### Helm preflight cascade (recovery pattern)
> *"Every Helm install wraps a status check. If the release is in `pending-install` or `pending-upgrade`, try `helm rollback`, if that fails do `helm uninstall`, then `helm upgrade --install`. Crashed Helm releases auto-recover."*

### ALB webhook stale state recovery
> *"The ALB Controller installs admission webhooks protected by TLS. When Helm crashes mid-install, the webhook configurations stay (they're cluster-scoped) but the TLS Secret can be missing. Every kubectl apply afterwards fails with TLS errors — the cluster is effectively locked. I detect with `kubectl apply --dry-run=server` and recover with a nuke-and-reinstall cascade — delete webhook configs, TLS secret, webhook service, and deployment, all with `--ignore-not-found` for idempotency, then `helm upgrade --install` fresh."*

### Stuck namespace force-finalize
> *"If the petclinic namespace is stuck in `Terminating` from a previous failed deploy with finalizers, my workflow waits up to 5 minutes for natural cleanup, then force-finalizes via `jq + kubectl replace --raw /api/v1/namespaces/petclinic/finalize` to clear finalizers. After cleanup, recreates the namespace."*

### Three chicken-and-eggs
> *"My project has three chicken-and-egg problems: the runner can't boot itself (GitHub-hosted wakes it up), the IAM OIDC Identity Provider can't be recreated if it already exists (conditional create with `count = var.X == "" ? 1 : 0`), and IRSA needs ordering — EKS cluster → OIDC issuer URL → IAM OIDC provider → IAM role → ServiceAccount annotation (`depends_on` chains + staged execution)."*

### EKS Access Entries (modern aws-auth)
> *"EKS Access Entries are the modern API for granting IAM principals Kubernetes access — replaces the old aws-auth ConfigMap. I attach `AmazonEKSClusterAdminPolicy` to my bootstrap CI role so kubectl works from the runner. Without this, AWS IAM accepts my role but EKS rejects it with 'Unauthorized.'"*

### STS credential refresh mid-workflow
> *"My bootstrap takes 22 minutes; STS credentials expire after 1 hour. I add a 'Refresh AWS credentials before readiness checks' step that re-authenticates via OIDC — fresh creds for the final stages. Without this, the last few kubectl commands would fail with expired token errors."*

### Secrets Manager → K8s Secret bridge
> *"My MySQL credentials live in AWS Secrets Manager. The bootstrap fetches them via `aws secretsmanager get-secret-value`, then creates a Kubernetes Secret with the values. Pods reference the K8s Secret via `secretKeyRef`. The bridge step is part of why ordering matters — the K8s Secret must exist before pods start."*

### `if: failure()` diagnostic dumps
> *"Every potential-failure section in my bootstrap has an `if: failure()` step that dumps pods, logs, events, secrets, and service accounts — all with `|| true` after each command so one failed dump doesn't stop the others. When the workflow fails at 2 AM, the entire debugging context is in the GitHub Actions logs. No SSH into the runner."*

### workflow_run chaining (e2e-smoke)
> *"My `e2e-smoke.yaml` workflow auto-triggers when `infra-bootstrap.yaml` succeeds — `on: workflow_run: workflows: [infra-bootstrap]: types: [completed]` plus an `if: github.event.workflow_run.conclusion == 'success'` guard. Three curl calls against the ALB validate the full path from public internet to ALB to Ingress to api-gateway to backend service to RDS."*

### The March 22 marathon (STAR opener)
> *"By March 21 I had all the pieces working separately. On March 22 I set out to build one-click bootstrap that takes the platform from `terraform destroy` to fully running Petclinic. I expected a few hours. I was wrong — it took the whole day and 20+ commits across 5 chapters: Identity, Certificates, Order, Paradox, Cleanup. Every recovery pattern in the resulting 635-line workflow came from a specific failure I debugged that day, not from theory."*

---

## Phase 5 — Argo Rollouts Canary Deployment

### Why canary (progressive delivery)
> *"Canary deployment is progressive delivery — traffic shifts in phases instead of all-or-nothing. My api-gateway runs as an Argo Rollouts canary because static CI checks (Sonar, Trivy, JaCoCo) catch CODE issues but not RUNTIME regressions like 5xx error spikes under real traffic. Canary catches those at 20% blast radius instead of 100% — 5x reduction in user impact."*

### Argo Rollouts vs Deployment (`kind: Rollout`)
> *"My api-gateway uses `kind: Rollout` (Argo Rollouts CRD), not `kind: Deployment`. A standard Deployment only supports RollingUpdate — bumps replicas with no traffic control. Rollout is pluggable: canary or blue-green strategies, integrated traffic management, AnalysisTemplate hooks for objective rollout gates."*

### The 3-service pattern
> *"Argo Rollouts canary needs 3 Services: `api-gateway-stable` routes to current version pods, `api-gateway-canary` routes to new version pods, `api-gateway` root that the Ingress targets. ALB splits traffic between stable and canary based on the Rollout's `setWeight`."*

### ALB trafficRouting integration
> *"My Rollout spec has `trafficRouting.alb` pointing at my `frontend-proxyr` Ingress. Argo Rollouts uses TargetGroupBindings from the AWS Load Balancer Controller to programmatically shift traffic between the stable and canary target groups. No DNS changes, no manual ALB edits — it's all controlled by setWeight values in the Rollout spec."*

### The 4 canary steps
> *"My canary steps are: `setWeight: 20` first (20% traffic to canary pods), `pause: { duration: 2m }` (let Prometheus scrape data), `analysis: ...` (PromQL queries via AnalysisTemplate), then `pause: {}` (indefinite manual approval). Net: 5 minutes at 20% before manual review."*

### AnalysisTemplate as a reusable CRD
> *"My AnalysisTemplate is `kind: AnalysisTemplate` with two args — `prometheus-address` and `canary-service`. Args make it reusable: the same template can analyze `vets-service-canary` or `customers-service-canary` just by passing different args. Single template, multiple consumers."*

### PromQL success rate query
> *"My first metric is canary-success-rate: `sum(rate(http_server_requests_seconds_count{service=canary-svc, status!~"5.."}[2m]))` divided by `clamp_min(sum(rate(... total ...)), 0.001)`. The `status!~"5.."` is a PromQL regex for 'status NOT matching 5xx'. Success condition: `result[0] >= 0.95`."*

### PromQL 5xx rate query
> *"Second metric is canary-5xx-rate: same shape but `status=~"5.."` in the numerator — matches 5xx (bad) responses. Success condition: `result[0] <= 0.01`. Both metrics together cover 'good requests are healthy' AND 'bad requests are minimal' — independent signals."*

### Why 95% / 1% thresholds
> *"95% success rate is the standard SLA floor for HTTP services. 1% 5xx rate is industry-typical for healthy services. Both expressed as decimals between 0 and 1 because PromQL rate ratios are decimals, not percentages. The boundary direction matters: success ≥ 0.95 (pass), 5xx ≤ 0.01 (pass)."*

### `failureLimit: 1` (strict abort)
> *"`failureLimit: 1` means one failed metric check aborts the rollout. Strict — appropriate for a portfolio where false-positive aborts are acceptable but false-negative promotes are not. Production with noisier traffic might bump to `failureLimit: 3` for noise tolerance."*

### `clamp_min` divide-by-zero protection
> *"`clamp_min(..., 0.001)` prevents division by zero when no traffic has hit the canary yet — returns a minimum denominator of 0.001 so the PromQL query doesn't blow up before the canary even gets traffic. Defensive math."*

### `pause: 2m` vs `pause: {}` (timed vs indefinite)
> *"Two pause types in my Rollout. `pause: { duration: 2m }` auto-resumes after the timer — used for pre-analysis data collection. `pause: {}` with empty braces is INDEFINITE — waits forever until a human runs `kubectl argo rollouts promote api-gateway`. Different semantics, same `pause` keyword."*

### Two-layer defense (auto + manual)
> *"Two-layer defense — automated catches definite failures with objective thresholds; humans catch 'this looks weird' — slow memory growth, unusual latency distributions, patterns that don't trip thresholds but feel off. Automation should EARN trust over time, not be granted it. For portfolio scope, the manual gate is appropriate; for a mature pipeline with comprehensive metrics, I'd remove it."*

### Rollback mechanics (immediate ALB shift)
> *"On abort, ALB shifts traffic from 80/20 stable/canary back to 100% stable in seconds — not phases. The old stable pods were never scaled down during canary, so 'rollback' is just 'stop sending new traffic to canary.' No pod restart, no cold-start latency. In-flight canary requests drain naturally."*

### AnalysisRun vs AnalysisTemplate (debugging)
> *"AnalysisTemplate is the SPEC (the YAML file I defined). AnalysisRun is an INSTANCE — one per rollout attempt. To debug a failed analysis, I run `kubectl describe analysisrun -n petclinic` (not analysistemplate) — shows the actual PromQL query results, which metric failed, which value triggered the abort."*

### The 4 diagnostic commands
> *"My canary debug toolkit: `kubectl argo rollouts get api-gateway` shows current state + abort reason; `kubectl argo rollouts get api-gateway -w` for live watch; `kubectl describe analysisrun -n petclinic` for PromQL results; `kubectl argo rollouts abort api-gateway` to manually kill a rollout."*

### Canary vs Blue-Green tradeoff
> *"I chose canary over blue-green for three reasons: cost (blue-green doubles infra; my budget is $20/month), blast radius (canary catches at 20% — 5x reduction), and automated analysis fits naturally with PromQL gates at intermediate weights. The tradeoffs I accepted: blue-green has INSTANT rollback (env flip vs traffic shift), and blue-green handles DB schema migrations easier because Green can be tested in isolation."*

### DB schema migration tradeoff
> *"Canary keeps old and new versions running simultaneously against the same DB — so schema changes must be backward-compatible. Adding columns works, renaming or dropping requires a 3-4 deploy expand/contract pattern: add new column → write to both → backfill → drop old. Blue-Green sidesteps this because old and new never run simultaneously; you migrate atomically during cutover. My canary is on api-gateway which is stateless — DB problem doesn't bite me. If I extended canary to DB-touching services, I'd need expand/contract or Blue-Green for that service."*

### The verify-infra-bootstrap gate
> *"My `api-gateway-canary.yaml` workflow has a `verify-infra-bootstrap` job that queries GitHub's API for the latest infra-bootstrap conclusion and fails if it wasn't 'success'. Don't deploy canary to a broken platform. Deployment dependency pattern — used by Netflix's Spinnaker."*

### The canary workflow trigger
> *"My canary workflow triggers on `push: branches: [main]` with `paths` filter on `kubernetes/api-gateway/**`. When my CI merges a PR with a new image tag (committed by the updatek8s bot), the canary workflow auto-fires. Plus `workflow_dispatch` for manual rollouts of unchanged manifests."*

---

## Phase 6 — RDS + Secrets Manager (Simple Language)

### Where the password lives
> *"The database password is stored in AWS Secrets Manager — never in my code, never in Git, never in Terraform files. AWS generates it for me when I set `manage_master_user_password = true`."*

### The 3 places involved
> *"Three places. AWS Secrets Manager has the real password. My bootstrap workflow copies it into a Kubernetes Secret called `mysql-credentials`. My pods read it from that Kubernetes Secret as environment variables. That's it."*

### How pods get the password (simple)
> *"My pods use `envFrom: secretRef` which means 'take every key from this Kubernetes Secret and turn it into an environment variable.' Spring Boot then reads those env vars automatically and connects to the database."*

### Why I used RDS instead of running MySQL in Kubernetes
> *"RDS is fully managed by AWS — they handle backups, encryption, patching, monitoring, and failover. If I ran MySQL inside Kubernetes myself, I'd have to build all of that. The $12/month I pay for RDS saves me hours of work I'd otherwise spend on database operations."*

### Five things AWS handles for me with RDS
> *"Backups happen daily, automated. Encryption is one Terraform flag. Failover is one flag (multi-AZ). Patching happens in a maintenance window. Monitoring comes free via CloudWatch. All of that would be weeks of work in Kubernetes."*

### Why my database isn't on the public internet
> *"My RDS sits in private subnets — no internet gateway route. Plus `publicly_accessible = false` ensures no public IP. So even if someone tried to reach it from the internet, there's no path. Only my Kubernetes pods inside the VPC can talk to it."*

### The security group rule
> *"My security group only allows MySQL traffic — port 3306 — and only from my VPC's IP range. Any other port, any traffic from outside my VPC, gets blocked at the firewall."*

### Five layers of defense
> *"Five layers protect my database. VPC isolation. Private subnets. Security group restricting port 3306 to VPC only. KMS encryption at rest. Password authentication from Secrets Manager. An attacker would need to break through all five to reach the data."*

### Why customer-managed KMS instead of free AWS-managed
> *"Customer-managed KMS costs $1/month but gives me full control over the encryption key policy — I decide who can decrypt. Compliance frameworks like SOC2 and HIPAA require this. AWS-managed is free but fails those audits."*

### Why single-AZ instead of multi-AZ
> *"Single-AZ saves $12/month — multi-AZ doubles the cost because AWS runs a synchronous standby copy in another availability zone. For my portfolio with no real users, single-AZ is fine. For production, I'd flip multi-AZ on for the 60-second failover."*

### Why 1-day backup
> *"1-day backup isn't really about cost — going to 7-day only adds a dollar. The real reason is it works with `skip_final_snapshot = true` and `deletion_protection = false`. Those three flags together let me destroy and rebuild the infrastructure easily during portfolio development."*

### The destroy-friendly trio
> *"I have three flags set up for easy teardown: `backup_retention_period = 1`, `skip_final_snapshot = true`, `deletion_protection = false`. Together they let me `terraform destroy` cleanly. In production I'd flip all three for 7-day backups, final snapshot taken, and deletion protection on."*

### How I'd defend my cost choices
> *"Every cost decision is deliberate against my $20/month budget. Multi-AZ is the biggest saver. Each choice has a specific trigger that would make me upgrade in production — real users, SLA commitments, compliance audits. Cost decisions are stage-appropriate, not permanent."*

### The rotation problem (the trap)
> *"AWS rotates the database password every 7 days for security. But here's the trap — my Kubernetes Secret holds the OLD password because the bootstrap only fetched it once. So after rotation, my Secret is stale."*

### Why rotation doesn't break pods immediately
> *"Here's the sneaky part. Existing pods keep working after rotation because MySQL doesn't re-check the password mid-session. The connection pool stays alive. The break only happens when a pod restarts and HikariCP tries to make a NEW connection with the old password."*

### When the rotation break actually shows up
> *"At rotation time, nothing visible. A few hours later when a pod restarts due to OOM or eviction, that pod fails to connect with 'Access denied for user admin'. Over the next few days as more pods cycle, more fail. By the next rotation 7 days later, the whole fleet is broken."*

### How I'd manually recover from a rotation break
> *"Three steps. Re-run my bootstrap workflow — it fetches the latest password from Secrets Manager and updates the Kubernetes Secret. Then `kubectl rollout restart deployment -n petclinic` to force pods to pick up the new password. Finally verify with `kubectl get pods` and `kubectl logs`. Takes about 5-10 minutes."*

### The production fix for rotation
> *"External Secrets Operator. It's a controller that watches Secrets Manager and automatically syncs the Kubernetes Secret when the password rotates. Plus Reloader detects the change and restarts the pods. Zero manual work on rotation. I haven't wired it for portfolio but it's mandatory in production."*

---

## Phase 7 — AIOps Foundation: EKS Access + CloudWatch (Simple Language)

### What Phase 7 actually does
> *"Phase 7 is the plumbing layer. It does two things — gives extra IAM principals access to my cluster, and ships my cluster's logs and metrics to CloudWatch so AWS-native tools can read them. Without it, my AIOps Service in Phase 8 has nothing to query and no way to authenticate."*

### Why I moved from aws-auth ConfigMap to Access Entries
> *"AWS deprecated the aws-auth ConfigMap in 2023. The old way required editing a YAML inside Kubernetes — one typo could lock everyone out. Access Entries are native AWS resources — every change shows up in CloudTrail, and AWS-managed policies replace handwritten RBAC."*

### How Access Entries work (the 2-part model)
> *"Two Terraform resources working together. `aws_eks_access_entry` declares 'this IAM role is known to the cluster.' `aws_eks_access_policy_association` declares 'this role has THIS level of access at THIS scope.' Both are required — Entry alone grants nothing."*

### The 5 AWS-managed access policies
> *"AWS provides five ready-made policies: ClusterAdmin (full power), Admin (within a namespace), Edit (edit within namespace, no secrets), View (read-only), and AdminView (read-only including secrets). I don't have to write RBAC YAML — just pick the policy that fits."*

### What I did and what I'd change for production
> *"Currently I grant cluster-wide admin to my human admin roles and my cost-ops automation role. For production I'd scope tighter — namespace admin for humans on petclinic only, view-only for the AIOps Service on petclinic and amazon-cloudwatch namespaces, custom limited policy for cost-ops."*

### IRSA in simple terms
> *"IRSA — IAM Roles for Service Accounts — is the 2019 way to let pods talk to AWS. The cluster has an OIDC issuer URL. You create an IAM OIDC provider pointing at it. You write a trust policy referencing that URL. You annotate the Kubernetes ServiceAccount with the IAM role ARN. The pod uses a special token to call STS and get temporary AWS credentials."*

### Pod Identity in simple terms
> *"Pod Identity — released 2023 — is AWS's simpler replacement. No OIDC URL, no annotation on the ServiceAccount. Just install the `eks-pod-identity-agent` add-on, write a simple trust policy with `pods.eks.amazonaws.com` as the principal, and use `pod_identity_association` to link the ServiceAccount to the IAM role. The agent runs on every node and injects credentials when pods ask for them."*

### The big difference between IRSA and Pod Identity
> *"With IRSA, the IAM role binding lives ON the Kubernetes ServiceAccount as an annotation. With Pod Identity, the binding lives in AWS — you don't touch the ServiceAccount at all. That's why Pod Identity roles work across clusters; IRSA roles don't because the OIDC URL is cluster-specific."*

### Why my project uses both
> *"My ALB Controller from Phase 3 uses IRSA because it's an older Helm-installed controller. My CloudWatch Observability from Phase 7 uses Pod Identity because it's a newer AWS-managed add-on. Knowing when to use which — and being able to coexist them in the same cluster — is the senior signal."*

### The 2 STS API calls
> *"IRSA calls `sts:AssumeRoleWithWebIdentity` — STS validates the OIDC token. Pod Identity calls `AssumeRoleForPodIdentity` on the EKS Auth API. Same end result — temporary AWS credentials — different mechanism."*

### Why Pod Identity needs `sts:TagSession`
> *"Pod Identity passes the Kubernetes ServiceAccount name as a session tag on every credential request. Without `sts:TagSession` permission in the trust policy, the AssumeRole call fails. The benefit — you can write IAM policies that condition on `aws:RequestTag/kubernetes-service-account` for super-tight access control."*

### What CloudWatch Observability installs
> *"One EKS add-on installs everything. A namespace called `amazon-cloudwatch`. Two DaemonSets — one CloudWatch Agent pod per node, one Fluent Bit pod per node. A shared ServiceAccount called `cloudwatch-agent` bound to my IAM role via Pod Identity. Multiple ConfigMaps with default settings."*

### CloudWatch Agent vs Fluent Bit
> *"Clean separation. CloudWatch Agent ships METRICS — pod CPU, pod memory, node CPU, network — to Container Insights. Fluent Bit ships LOGS — tails container stdout and stderr — to CloudWatch Logs. Different jobs, same auth, both on every node."*

### The 3 CloudWatch log groups
> *"Fluent Bit ships to three log groups. `application` has my Petclinic container logs — this is what AIOps queries. `dataplane` has kubelet and container runtime logs. `host` has node OS logs. Each scoped to a layer."*

### Where Fluent Bit reads logs from
> *"Fluent Bit tails `/var/log/containers/*.log` on each node — that's where kubelet writes container stdout and stderr. Each log line gets enriched with Kubernetes metadata — namespace, pod name, container name, labels — before being shipped to CloudWatch."*

### Why I use the EKS add-on instead of Helm
> *"Three ways to install CloudWatch Agent — EKS add-on, Helm chart, manual YAML. I chose the add-on because AWS manages the version lifecycle, K8s compatibility, and IAM integration. Helm requires me to manage release state. Manual YAML requires me to own everything. The add-on saves engineering hours."*

### The 6 reasons for the EKS add-on
> *"Six wins. AWS manages version upgrades. IAM integration via `pod_identity_association`. K8s compatibility matrix validated by AWS. Sensible default configs. Container Insights dashboards auto-created. Failure mode observable via `aws eks describe-addon`. My bootstrap workflow gates on this last one."*

### What the add-on doesn't let me do
> *"Tradeoffs accepted. Limited config flexibility — the `configurationValues` block has a fixed schema. Tied to AWS's release cadence — I can't pull a newer Fluent Bit version than what AWS has packaged. If I needed custom log transformations, I'd drop to Helm."*

### How Phase 7 connects to Phase 8 (the bridge)
> *"Four pieces of Phase 7 become Phase 8's foundation. CloudWatch Observability's logs become the AIOps Logs Insights data source. The ContainerInsights metrics namespace becomes the GetMetricData data source. The Pod Identity Agent becomes the auth mechanism for the AIOps IAM role. The Access Entries pattern becomes the template for AIOps cluster access."*

### The 3 gaps Phase 7 fills before Phase 8 can exist
> *"AIOps needs data, auth, and access. Without Phase 7's CloudWatch add-on, AIOps queries empty log groups. Without Phase 7's Pod Identity Agent, AIOps can't authenticate to AWS APIs. Without Phase 7's Access Entries, AIOps can't reach the Kubernetes API. Three gaps, all filled by Phase 7."*

### The principle (the killer one-liner)
> *"Plumbing first, features second. That's how production systems get built. Phase 7 is invisible until it's missing. Skipping it would mean building Phase 8 against a broken foundation."*

### The bootstrap fix story
> *"My second bootstrap run failed with `EntityAlreadyExistsException` because Terraform tried to create an Access Entry that already existed. Same class of bug as my Phase 1 OIDC provider problem — both surface only on cold-start vs warm-start re-runs. Fixed with `terraform import` plus the for_each idempotency pattern."*

---

## Phase 8 — AIOps Service + Streamlit UI (Simple Language)

### What Phase 8 actually does
> *"Phase 8 is the AI-powered incident assistant. A Spring Boot service gathers evidence from Kubernetes, CloudWatch logs, and Prometheus, hands it to AWS Bedrock with a constrained prompt, and Bedrock synthesizes a probable root cause. A Streamlit UI lets engineers type natural-language questions and see the diagnosis."*

### The 8-layer flow
> *"Eight layers. Streamlit UI sends a POST /query with JSON. Spring validates via @Valid. AiopsQueryController forwards to AiopsQueryService. The orchestrator calls 3 adapters — Kubernetes health, CloudWatch logs, Prometheus metrics. Evidence flattened. BedrockReasoningService synthesizes via Converse API with temperature 0.3. AiopsQueryResponse returns 6 fields. Streamlit renders 6 sections."*

### The thin controller pattern
> *"AiopsQueryController is one line of business logic — it validates the request via @Valid and forwards to the service. Thin controllers separate transport from business logic. I could replace HTTP with gRPC tomorrow without touching the orchestrator."*

### The orchestrator's job (the brain)
> *"AiopsQueryService is the brain. It calls 3 adapters in sequence, flattens their EvidenceSection results into one list, sends to Bedrock for AI synthesis, runs a failure-classification ladder based on which adapters succeeded or failed, then builds the structured response."*

### Why 3 adapters with interfaces (Strategy pattern)
> *"Three adapters with interface + implementation split. Interface defines WHAT — fetchLogs returns EvidenceSection. Implementation defines HOW — actual SDK calls. The orchestrator depends on the LogsAdapter interface, not the CloudWatch implementation. Three benefits: separation of concerns, testability, swappability."*

### The killer phrase for interfaces
> *"The orchestrator doesn't know it's calling CloudWatch. It only knows the LogsAdapter shape. Swap CloudWatch for Splunk tomorrow — one new class, orchestrator unchanged."*

### Why interfaces enable testing
> *"With interfaces, I can write a fake LogsAdapter in 3 lines that returns canned data, inject it for unit tests. Tests run in milliseconds without real AWS or K8s. Without interfaces, every unit test would need real infrastructure — slow tests, no tests, bugs."*

### Why interfaces enable swappability (Strategy pattern)
> *"Strategy pattern from Gang of Four — a family of interchangeable algorithms behind a common interface. CloudWatch could be Splunk, Datadog, Elasticsearch. Prometheus could be Datadog metrics or New Relic. Kubernetes could be Nomad or ECS. The orchestrator code never changes."*

### Single Responsibility + SOLID
> *"Demonstrates SOLID — Single Responsibility on each adapter (one reason to change), Open/Closed (orchestrator open to new adapters, closed to modification), Interface Segregation (tiny one-method interfaces), Dependency Inversion (orchestrator depends on abstractions not concretions)."*

### Adapters = HOW, Interfaces = WHAT
> *"Mental model — adapters have the HOW factor: actual SDK logic. Interfaces have the WHAT factor: just the shape, no code. The orchestrator depends on the WHAT."*

### The 3 evidence sources
> *"Three sources covering different layers. KubernetesServiceHealthAdapter queries the K8s API via Fabric8 for deployment status and pod restart counts. CloudWatchLogsAdapter calls AWS SDK FilterLogEvents against the application log group. PrometheusMetricsAdapter queries Prometheus HTTP for 5xx rate, p95 latency, and request rate."*

### The 3 Prometheus metrics
> *"Three industry-standard service metrics — 5xx error rate, p95 latency, request rate. Same metrics my Phase 5 canary analysis uses. Consistent observability vocabulary across phases."*

### Why Converse API over InvokeModel
> *"Converse is provider-agnostic — same call shape for Claude, Llama, Titan. InvokeModel requires per-model JSON serialization where Claude's format differs from Llama's. With Converse, switching models is a config change, not a code rewrite."*

### Why temperature 0.3
> *"Temperature controls token sampling randomness. Zero is fully deterministic, one is creative. I picked 0.3 as the balance — diagnostic recommendations grounded in evidence, not creative guesses. For incident analysis, creative root causes are dangerous."*

### The 6 prompt constraints
> *"Six constraints, each addresses a specific LLM failure mode. Role priming sets the AIOps incident assistant persona. Grounding tells the model to use ONLY supplied evidence. Anti-hallucination explicitly says do not invent facts. Honesty enforcement permits the model to admit telemetry gaps. The killer line — 'do not confuse missing observability with application bug' — prevents the subtle failure where Bedrock blames the app when telemetry is broken. Format constraint bounds the output to one sentence."*

### The killer prompt line (memorize verbatim)
> *"Do not confuse missing observability data with an application bug. Without this line, when CloudWatch is down, Bedrock sees no logs and blames the app — but the app is fine; the telemetry is broken. This line is the most important constraint in the prompt."*

### Anti-hallucination as production safety
> *"Hallucination in production observability is dangerous — it points engineers at the wrong fix. My prompt explicitly grounds the model to supplied evidence and forbids invention. Production-context reasoning, not generalized AI guessing."*

### Failure handling (graceful degradation)
> *"Try/catch around the Bedrock call. If anything throws — IAM error, throttling, wrong region, network timeout — the error message becomes the probableRootCause string. HTTP request doesn't crash. Evidence still flows back. Graceful degradation."*

### Bedrock cost per query
> *"About $0.0006 per query with Claude Haiku. Input ~1750 tokens, output ~100 tokens. At 1000 queries/day, ~$18/month. Rounding error against the value of automated incident analysis."*

### The IAM auth chain (Phase 7 tie-in)
> *"Auth via Pod Identity from Phase 7. The AIOps pod's IAM role has bedrock:Converse scoped to the specific model ARN, logs:FilterLogEvents on the application log group ARN, and view access on the petclinic namespace via Access Entries. Least privilege."*

### Why Streamlit (not React)
> *"Streamlit is Python, 80 lines for the entire UI. Production would swap for React or Angular for end-user-facing apps. For an internal AIOps tool used by engineers, Streamlit's perfect — 80 lines vs 500, no build pipeline, fast to iterate."*

### The 6-field response DTO
> *"AiopsQueryResponse has 6 fields — probable root cause, evidence collected, impacted services, recommended fix, confidence level, known unknowns. Structured output that maps directly to what Streamlit renders. Strict typing means the contract is enforced at compile time."*

### The failure-classification ladder
> *"The orchestrator runs an 11-case if/else ladder checking marker strings in evidence — 'Failed to query CloudWatch Logs' or 'Deployment not found' map to specific response templates with confidence levels and recommended-fix lists. Defensive design — service answers gracefully even with partial telemetry."*

### Honest sequential vs parallel gap
> *"Adapters currently run sequentially — each completes before the next starts. ~10 seconds total. Production fix is CompletableFuture.allOf to parallelize since the 3 sources are independent. Would cut latency to about 7 seconds. Portfolio shortcut."*

### Honest production gaps for AIOps
> *"No streaming responses, no retry logic beyond AWS SDK defaults, no prompt caching, no model fallback, no conversation memory, no tool-use loop, no vector store for historical incidents. Production iterations — converseStream for UX, Bedrock prompt caching for 90% cost reduction, fallback chain through cheaper models, Resilience4j for retry and circuit breakers, RAG for historical context."*

### Phase 7 → Phase 8 dependency chain
> *"Phase 8's value depends entirely on Phase 7's foundation. Without CloudWatch Observability add-on, log queries return empty. Without Pod Identity Agent, the AIOps pod can't authenticate to Bedrock. Without Access Entries, it can't reach the K8s API. Plumbing first, features second."*

### The killer failure-handling principle
> *"Failures become evidence, not exceptions. Each adapter has a try/catch that converts errors into observation strings. The orchestrator never receives a raw exception — it reads observations uniformly, some describing healthy data, some describing failures."*

### How my AIOps avoids the AI-lies problem
> *"The most common failure of AI-driven observability is the AI lies when telemetry is broken. Bedrock without constraints would diagnose a healthy app as broken because it sees no logs — when really CloudWatch is down. My design surfaces telemetry gaps as FACTS in the evidence list, not as inferred app bugs."*

### The 4-step graceful degradation pattern
> *"Four steps when a source fails. One — acknowledge the failure explicitly. Two — confidence drops to low. Three — surviving adapters still contribute results. Four — list unknowns and recommended fixes for investigation. Failures don't hide; they surface."*

### The 6 marker strings detection
> *"Six marker strings drive failure classification. Three 'Failed to query X' markers — one per adapter for CloudWatch, Kubernetes, Prometheus. Plus 'Deployment not found,' 'No matching log events,' and 'no data.' Six boolean flags map to eleven response templates."*

### The 11-case classification ladder
> *"Eleven response templates. All three failed = low confidence, unable to determine. Two failed = three sub-cases by which pair. Deployment missing = medium confidence because sources work, just wrong workload. One failed = three sub-cases by which one. Everything worked = medium with telemetry retrieved."*

### Low vs medium confidence rule
> *"Low confidence when an adapter FAILED to query — the telemetry layer is broken, can't trust diagnosis. Medium confidence when telemetry worked but data was absent — workload genuinely emitted nothing. No 'high' path is the honest gap; production should add one when all three adapters return rich data plus LLM consensus."*

### The Bedrock override pattern (layered design)
> *"Bedrock writes the probableRootCause sentence — the diagnosis. My classifier writes the metadata — confidence, recommendedFix list, unknowns list. Layered design where each layer does what it's good at. The user sees Bedrock's diagnosis as the headline, the classifier's metadata as the support structure."*

### Why honest failure communication matters
> *"Auditors require explicit failure logging in regulated industries. 'We diagnosed despite gaps with documented gaps' is acceptable. 'We diagnosed and didn't notice telemetry was broken' is a compliance violation. Honest failure communication isn't optional — it's the audit trail."*

### Production gap: string-based marker matching
> *"String-based marker matching is fragile. If I typo one error message, the orchestrator silently mis-classifies. Production fix is a Status enum on EvidenceSection — type-safe, IDE-refactorable. My current approach is a deliberate portfolio shortcut."*

### Production gap: no retry / circuit breaker
> *"No retry before failing — Resilience4j would add three attempts before falling to failure observation. No circuit breaker — if CloudWatch is broken, every query waits the full 30-second timeout. Production fix is Resilience4j's circuit breaker pattern — fast-fail after detecting sustained failure."*

### The trust-destroying failure mode
> *"AI-driven observability tools that lie about broken telemetry destroy trust faster than no tool at all. Once engineers see one wrong-confidently diagnosis, they stop trusting every diagnosis. The whole tool becomes useless. My design prioritizes honest failure communication over confidently-wrong diagnoses."*

### The MECE 3-category production framework
> *"Three categories of gap before production-ready. Performance and reliability — parallel adapters, timeouts, retry. Meta observability — metrics, structured logs, alarms on the AIOps service itself. LLM operational maturity — model fallback, Guardrails, RAG."*

### The meta-observability killer insight
> *"My AIOps service monitors other services. Who monitors mine? Without observability on my own service, I won't know whether an issue is with the application or with AIOps itself. Recursive observability is mandatory."*

### Parallel adapters (Week 1)
> *"Adapters run sequentially today — total latency ~10 seconds. CompletableFuture.allOf parallelizes the three independent sources. Latency drops to ~5 seconds. Half-day of code for a 50% user-facing latency win."*

### Per-call timeouts (Week 1)
> *"Currently relying on AWS SDK defaults of 30 seconds. Production fix: Kubernetes 5 seconds, CloudWatch 10 seconds, Prometheus 5 seconds, Bedrock 15 seconds with one retry, total request budget capped at 30 seconds."*

### Resilience4j for retry + circuit breaker (Month 1)
> *"Resilience4j with exponential backoff retry — 3 attempts with 500ms initial wait. Circuit breaker that fast-fails after 50% failure rate in 10-call window. Cuts pathological latency from 30 seconds to 1 second when a source is sustained-down."*

### Micrometer metrics on the AIOps service (Week 1)
> *"Spring Boot Micrometer exposing aiops_query_count, aiops_adapter_failure_count per adapter, aiops_low_confidence_rate, aiops_bedrock_token_count for cost tracking. Auto-publishes to CloudWatch — observability of the observability."*

### Structured JSON logging (Week 1)
> *"Default Spring logging today. Production fix: structured JSON with query_id UUID, per-adapter latency, Bedrock prompt and response sizes, final confidence. Feeds CloudWatch Logs Insights queries for post-incident review."*

### CloudWatch alarms + PagerDuty (Month 1)
> *"Alarms on adapter failure rate above 5%, p95 latency above 15 seconds, Bedrock cost anomaly. All wired to SNS for PagerDuty on-call escalation. Latency 15-second threshold matches my 30-second total budget — alerts before user pain."*

### Authentication on /query (Month 1)
> *"No auth today. Production: JWT validation at ingress level via OIDC. Audit who logged in and exactly what they queried. Critical for compliance industries and multi-user environments."*

### Model fallback chain (Quarter 1)
> *"Only Claude Haiku today. Production: fallback chain Haiku → Llama 3 → template-only response via Resilience4j Fallback decorator. Llama 3 is actually cheaper than Haiku — fallback also saves money during throttling."*

### Bedrock Guardrails for hallucination defense (Quarter 1)
> *"Bedrock Guardrails for content filtering, PII redaction, grounding score against input context. Reject low-grounding responses or flag with reduced confidence. Mandatory for regulated industries."*

### RAG with historical incidents (Quarter 1)
> *"Vector store of historical incidents in Bedrock Knowledge Base or OpenSearch Serverless. Retrieve similar past incidents, add as context to Bedrock. Bedrock can say 'this looks like incident-1234 from last month, fixed by X' — huge user value, ~$80/month cost."*

### Prompt caching (Deferred)
> *"Bedrock prompt caching with cachePoint blocks on the static system prompt. Up to 90% cost reduction on the cached portion. Saves $5/month at portfolio scale; saves ~$500/month at 100K queries/day. Scale-dependent optimization."*

### Streaming responses (Deferred)
> *"converseStream API streaming tokens to Streamlit via Server-Sent Events. First token in ~1 second vs full response in ~5 seconds. UX win, not correctness win."*

### Tiered prioritization (the senior frame)
> *"Week 1: parallelization, timeouts, metrics, structured logs. Month 1: Resilience4j, alarms, auth. Quarter 1: RAG, Guardrails, model fallback. Deferred: prompt caching, streaming, conversation memory. Tier by cost-of-not-fixing, not by what's cool to build."*

### The 80/20 senior framing
> *"80% of production value comes from standard production patterns — parallelization, timeouts, retry, metrics, structured logs, auth. None of that is AI-specific. The fancy stuff like RAG and prompt caching matters at scale, not at MVP."*

### Cost-of-not-fixing prioritization
> *"Prioritize by cost-of-not-fixing, not by what's cool to build. Sequential adapters = 5 extra seconds per query. No retry = 30-second hangs on transient failures. No metrics = silent degradation. No auth = security incident waiting. Cost of leaving broken drives the order."*

---

## GitHub Actions Mechanics

### What's a runner?
> *"A runner is the server that actually executes a workflow's jobs. GitHub-hosted runners are ephemeral Ubuntu VMs provisioned per job — free for public repos. Self-hosted runners are machines I provision myself; I use one in my project specifically because my EKS cluster has a private API endpoint that GitHub-hosted runners on the public internet can't reach."*

### Trivy installation
> *"Trivy is referenced via the official GitHub Action `aquasecurity/trivy-action@v0.25.0` — pinned version, no persistent install. The action downloads the Trivy CLI binary into the ephemeral runner on each workflow run."*

### SonarCloud installation
> *"SonarCloud is the SaaS at sonarcloud.io plus the Maven `sonar:sonar` plugin auto-fetched from Maven Central. Token, host URL, org, and project key live as GitHub Secrets; the Maven plugin uses them to upload scan results."*

### OIDC auth (with AWS)
> *"OIDC replaces long-lived AWS access keys with short-lived federated credentials. My workflow requests a signed JWT from GitHub, hands it to AWS STS via `AssumeRoleWithWebIdentity`, and gets back one-hour credentials. The trust policy condition restricts the role by repo and branch via the JWT's `sub` claim, so even if the role ARN leaked, attackers can't assume it from a different repo."*

### GitHub Actions cron
> *"GitHub Actions cron is UTC-only with no native timezone support. I use a two-cron pattern — one for CST, one for CDT — plus an internal `TZ=America/Chicago` time check that exits early if the local hour doesn't match. This ensures the workflow fires exactly once per day at 11 PM Chicago, regardless of daylight saving."*

---

## Power Phrases

Drop these anywhere in any interview. Each signals senior-level thinking:

| Topic | Phrase |
|---|---|
| GitOps | *"Git is the source of truth; the cluster is a downstream artifact"* |
| GitOps | *"CI builds and updates git; CD deploys from git"* |
| Rollback | *"Rollback becomes `git revert`"* |
| Security | *"The registry is a trust boundary"* |
| Security | *"Defense in depth — different attack surfaces"* |
| Security | *"Scan-before-push is the gate; scan-after-push is visibility"* |
| Cost | *"Cost is a CI gate, not a dashboard people forget to check"* |
| Cost | *"FinOps as code"* |
| IAM | *"Attribute-Based Access Control via tag conditions"* |
| IAM | *"Trivy:ignore with reasoning — audit trail, not silent suppression"* |
| OIDC | *"Federated credentials, not stored secrets"* |
| Pods | *"Pod Security Standards Restricted profile"* |
| Quality | *"`wait=true` makes the gate enforceable, not advisory"* |
| Idempotency | *"Idempotent recovery — every step is safe to re-run"* |
| Compliance | *"NIST SSDF / CISA recommended pattern"* |
| Architecture | *"YAGNI — proved the pattern in one service before templatizing"* |
| Operations | *"One click brings the whole platform up; one click tears it down"* |
| Drift | *"Argo CD detects drift in real time"* |
| Multi-cluster | *"Same git, different reconcilers"* |
| Image identity | *"Run_id is the canonical link between an image and its provenance"* |

---

## "Famous CVEs" to namedrop

- **Log4Shell** — `CVE-2021-44228` — log4j2 RCE, CVSS 10.0, Dec 2021
- **Spring4Shell** — `CVE-2022-22965` — Spring Framework RCE
- **runc container escape** — `CVE-2024-21626` — early 2024 K8s/Docker
- **Heartbleed** — `CVE-2014-0160` — OpenSSL memory exposure

---

## "Famous attacks" to mention

- **Pwn Request** — Forked PR modifies workflow file to exfiltrate the bot's GITHUB_TOKEN
- **Supply chain attack** — Compromised upstream dependency injects malicious code (Log4Shell, SolarWinds, xz utils)
- **Container escape** — runc bug lets a process inside a container access the host filesystem

---

## Future updates

When you complete more phases, add their one-liners here. Suggested order:
- Phase 3: Private EKS + self-hosted runner
- Phase 4: Bootstrap stabilization
- Phase 5: Argo Rollouts canary
- Phase 6: RDS + Secrets Manager
- Phase 7: AIOps foundation
- Phase 8: AIOps Service + Streamlit UI
