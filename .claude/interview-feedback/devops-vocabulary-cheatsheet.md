# DevOps Vocabulary — Interview Cheatsheet

Quick-reference with definitions and examples from YOUR project. Practice saying these out loud.

---

## Shift Left

**Definition:** Move testing, security, and quality checks earlier in the development lifecycle.

**Your project:** "I run SonarQube and Trivy scans during CI — before the image reaches Docker Hub. I specifically moved my Trivy image scan to run before the push, so a vulnerable image never reaches the registry. That's shift-left security."

---

## Blast Radius

**Definition:** How much damage a failure causes. Smaller is better.

**Your project:** "My canary deployment limits blast radius to 20% of users. Memory limits on pods ensure one leaky pod gets OOMKilled without crashing the node. Separate namespaces (petclinic vs monitoring) isolate failures between application and observability."

---

## Toil

**Definition:** Repetitive manual work that could be automated. Scales linearly, adds no lasting value.

**Your project:** "I eliminated toil by automating infrastructure with Terraform, CI/CD with GitHub Actions, and node scaling with cron workflows. My non-prod-stop and non-prod-start workflows automatically scale nodes to zero at night and back up in the morning — no manual intervention."

---

## SLI / SLO / SLA

**Definition:**
- SLI = what you MEASURE (e.g., 99.2% success rate)
- SLO = what you TARGET internally (e.g., aim for 99.5%)
- SLA = what you PROMISE customers with consequences (e.g., guarantee 99.9% or refund)

**Your project:** "My AnalysisTemplate measures the HTTP success rate (SLI) and checks it against a 95% threshold (SLO). If the canary drops below 95% success, the rollout aborts automatically. This is an automated SLO enforcement."

---

## Golden Signals

**Definition:** Four key metrics for monitoring any service (from Google SRE):

| Signal | Measures | Your project |
|--------|----------|-------------|
| Latency | How long requests take | http_server_requests_seconds histogram |
| Traffic | Request volume | rate of http_server_requests_seconds_count |
| Errors | Failure rate | canary-5xx-rate query in AnalysisTemplate |
| Saturation | Resource fullness | CPU/memory approaching pod limits |

**Your project:** "I monitor the golden signals through Prometheus and Grafana. My canary analysis specifically checks two of the four — errors (5XX rate <= 1%) and a success rate threshold (>= 95%). For saturation, I set resource requests and limits on every pod."

---

## MTTR / MTBF

**Definition:**
- MTBF = Mean Time Between Failures — how often things break
- MTTR = Mean Time To Recovery — how fast you fix it

**Your project:** "My canary deployment with Argo Rollouts minimizes MTTR. If the new version fails health checks, it auto-aborts and shifts traffic back to stable in under 2 minutes — no human intervention needed. I focus on reducing MTTR rather than preventing every failure."

---

## Immutable Infrastructure

**Definition:** Never modify a running server. Build a new one and replace it.

**Your project:** "Every deploy creates new pods with a new image tag — I never SSH into a running container. My readOnlyRootFilesystem: true enforces this at the Kubernetes level. If a pod is broken, I replace it, I don't patch it. Even my GitHub runner EC2 instance can be replaced with terraform apply -replace."

---

## Terraform Operational Commands

### terraform import
**What:** Adopt an existing AWS resource into Terraform state without recreating it.
**When:** Bringing manually-created resources under IaC management.
**Say:** "I would write the resource block matching the existing config, run terraform import with the resource address and AWS ID, then terraform plan until I get 'no changes' — confirming the code matches reality."

### terraform state mv
**What:** Rename a resource in state without destroying/recreating it.
**When:** Refactoring Terraform code (renaming resources or moving into modules).
**Say:** "If I rename aws_vpc.main to aws_vpc.this in code, I run state mv first so Terraform updates the mapping instead of destroying and recreating the VPC."

### terraform apply -replace
**What:** Force destroy and recreate a specific resource.
**When:** Resource is broken or corrupted but Terraform thinks it's fine.
**Say:** "If my GitHub runner EC2 instance is behaving strangely, I run terraform apply -replace to get a clean instance instead of SSH-ing in to debug. That's immutable infrastructure."

### terraform state rm
**What:** Remove a resource from state without deleting it in AWS.
**When:** Terraform should stop managing a resource (someone else will manage it).
**Say:** "If we're migrating a database to a different team's Terraform workspace, I'd state rm it from ours so we don't accidentally destroy it."

---

## How to Use This in Interviews

**Pattern for any vocabulary question:**
1. Define it in one sentence
2. Give a specific example from your project
3. Mention the tradeoff or why it matters

**Example:** "Shift left means catching issues earlier in the pipeline. In my project, I run Trivy scans during CI before pushing images — so vulnerabilities are caught in the build, not in production. The tradeoff is slightly longer CI times, but that's worth it compared to a security incident."
