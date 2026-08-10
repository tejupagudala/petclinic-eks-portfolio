---
date: 2026-04-02
round: technical
verdict: BORDERLINE
score: 5/10
comp_120k: Not Ready - Close
comp_165k: Not Ready
---

# Interview Session: Technical Deep-Dive -- 2026-04-02

## Market Context
Companies hiring AWS DevOps engineers at $120K-$165K in 2026 are heavily focused on EKS operational depth, Terraform at scale, GitOps/Argo workflows, and security-first infrastructure. PromQL/observability literacy is increasingly table-stakes as platform engineering matures. Candidates at this range are expected to operate and debug, not just deploy.

## Questions & Evaluation

### Q1: EKS Architecture & Networking
**Question**: Walk me through how a request from the internet reaches your visits-service pod, including every AWS and Kubernetes component involved.
**Candidate Answer Summary**: Described ALB, node groups, basic routing. Understood the high-level flow.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Correct mental model at high level. Missing: ALB Ingress Controller reconciliation, target group binding, kube-proxy/iptables rules, CoreDNS resolution, CNI pod networking (VPC CNI assigns ENI secondary IPs). Did not mention security groups at each layer.

### Q2: Terraform State Management
**Question**: Your Terraform state file gets corrupted and a teammate is running apply simultaneously. Walk me through your state management setup and how you handle this.
**Candidate Answer Summary**: Knew S3 backend with DynamoDB locking. Understood why remote state matters.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Correct on basics. Missing: state file recovery from S3 versioning, `terraform force-unlock`, `terraform state pull/push`, `terraform import` for drift, workspace strategies. Could not explain DynamoDB lock table schema (LockID partition key).

### Q3: IAM & Security (Least Privilege)
**Question**: How does your EKS workload (e.g., a pod that needs to read from S3) get AWS permissions? Explain the IRSA flow.
**Candidate Answer Summary**: Understood that pods should have minimal permissions. Generic answer about "only give what's needed."
**Rating**: Weak
**Score**: 4/10
**Notes**: Could not explain: OIDC provider on EKS cluster, IAM role trust policy with `sts:AssumeRoleWithWebIdentity`, service account annotation `eks.amazonaws.com/role-arn`, projected service account token volume, STS token exchange. This is a fundamental EKS security pattern that exists in the candidate's own Terraform.

### Q4: CI/CD Pipeline Design
**Question**: Describe your CI/CD pipeline end to end. What happens from git push to production traffic?
**Candidate Answer Summary**: Described GitHub Actions stages: build, test, scan, push image, update k8s manifests, canary deploy.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Good high-level description matching the actual pipeline. Missing depth on: image tag strategy and why commit SHA, Trivy scan thresholds and what fails the build, how the canary workflow triggers (separate workflow on main push), Argo Rollouts promotion flow, rollback automation vs manual approval.

### Q5: Container Security & Pod Security
**Question**: Your pods run as non-root with read-only rootfs. Explain what each security context field does and why it matters.
**Candidate Answer Summary**: Knew non-root is important for security. Could not explain specific fields.
**Rating**: Weak
**Score**: 4/10
**Notes**: The candidate's own pod specs include `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, `seccompProfile: RuntimeDefault`, and `drop: ["ALL"]` capabilities. Could not explain what seccomp does, why dropping capabilities matters, or how read-only rootfs affects Spring Boot (needs writable /tmp). These are in the candidate's own YAML files.

### Q6: Monitoring & Observability - Production Debugging
**Question**: Your visits-service is showing a 30% error rate in production. Walk me through exactly how you investigate using your monitoring stack.
**Candidate Answer Summary**: "Look at API request logs, healthy status, CPU, memory, disk. Also look at traces. Logs, metrics, traces will identify the issue."
**Rating**: Weak
**Score**: 3/10
**Notes**: Entirely generic. Zero specific Prometheus metrics named. Zero PromQL queries (despite having them in own analysis-template.yaml). Claimed tracing capability that does not exist in the stack (no Jaeger/Zipkin/OpenTelemetry). Did not mention kubectl commands (logs, describe, top) as first-line investigation. Did not hypothesize likely causes (1 of 3 pods unhealthy = ~33% error rate, HikariCP pool exhaustion, RDS connection limits on db.t4g.micro). This answer would fail at any company.

## Overall Assessment

The candidate has built a legitimate portfolio project with real infrastructure — EKS, Terraform, Argo Rollouts canary deployments, CI/CD, and monitoring. This is genuinely impressive for 6 months of experience and demonstrates initiative and ambition. The architecture decisions are sound and the project covers the right topics for the target role.

However, the candidate's knowledge is approximately one inch deep across the entire stack. Every answer follows the same pattern: correct high-level understanding, then inability to provide specifics when pushed. This is the hallmark of someone who built the system by following guides or using AI assistance (which is fine for learning) but has not yet internalized HOW and WHY things work at the operational level. The most damaging example: the candidate could not reference PromQL queries that exist in their own analysis-template.yaml, and claimed tracing capabilities their stack does not have.

For $120K, the candidate is close but not ready today. The conceptual understanding is there. The project is there. What is missing is hands-on operational depth — the ability to type commands, write queries, read configs, and debug issues without looking things up. This is a 2-4 week gap that can be closed with focused, hands-on practice on the existing infrastructure. For $165K, the candidate needs several more months of depth and likely production incident experience.

## Action Items for Next Session

- [ ] Study: Every line of kubernetes/api-gateway/analysis-template.yaml — memorize the PromQL queries and understand each function (rate, sum, clamp_min)
- [ ] Study: IRSA flow end-to-end — read AWS docs on EKS Pod Identity and OIDC providers, then trace through own Terraform EKS module
- [ ] Practice: Port-forward to Prometheus and run live PromQL queries against Spring Boot Actuator metrics
- [ ] Practice: kubectl debugging commands — logs, describe, top, exec, port-forward — until they are muscle memory
- [ ] Review: Own pod security contexts in kubernetes/*/deploy.yaml — explain every field without looking it up
- [ ] Review: Terraform state commands — force-unlock, state list, state show, state pull, state rm, import
- [ ] Study: AWS IAM policy evaluation logic, trust policies, condition keys (aws:SourceArn, aws:PrincipalOrgID)
- [ ] Practice: Run a behavioral/STAR round next to prepare the non-technical side of interviews

## Study Session Progress (2026-04-03 to 2026-04-05)

Interactive study session completed after the interview. Topics covered with Q&A:

### CVE & Trivy ✅ Solid Understanding
- Understands CVE = standardized vulnerability IDs with CVSS severity scores
- Knows all 4 Trivy scan types in the pipeline (fs, config-k8s, config-terraform, image)
- Understands `exit-code: '1'` (fail pipeline) vs `'0'` (warning only)
- Understands `ignore-unfixed: true` — skip CVEs with no available patch
- **Identified a real pipeline issue**: Trivy image scan runs AFTER docker push — image reaches registry before scanning
- **Fix applied to ci.yaml**: Split into build (push: false, load: true) → Trivy scan → push only if clean

### Terraform State Locking ✅ Solid Understanding
- Understands `use_lockfile = true` (S3 native, .tflock file, conditional writes via If-None-Match header)
- Understands DynamoDB approach (legacy, extra cost/complexity) and why `use_lockfile` is better
- Knows `terraform force-unlock <LOCK_ID>` and to verify no active operation before running it
- Knows `encrypt = true` = server-side encryption (SSE), not client-side
- Understands the full crash recovery flow: verify lock is stale → force-unlock → terraform plan → reconcile

### Canary Deployments (Argo Rollouts) ✅ Solid Understanding
- Knows the 3-service pattern: api-gateway (root), api-gateway-stable, api-gateway-canary
- Knows full step sequence: 20% → manual pause → 50% (30s) → 80% (30s) → 100%
- Understands AnalysisTemplate: count=3, failureLimit=1 means "3 checks, 1 mulligan"
- Understands success condition: `result[0] >= 0.95` = 95%+ requests must succeed
- Knows `pause: {}` = manual approval, `pause: {duration: 30s}` = automatic
- Understands traffic splitting happens at service level, not pod level

### IRSA ✅ Studied (Not Yet Quizzed)
- Walked through the full chain using actual Terraform code (main.tf lines 59-97)
- OIDC provider → trust policy with namespace/SA conditions → IAM role → projected token → STS AssumeRoleWithWebIdentity → temp credentials

### VPC Networking ⏸️ Paused — Needs Slow Revisit
- Understands NAT gateway purpose and basic flow
- Struggled with route table matching logic (specific route vs default route)
- Requested to revisit this topic slowly in a future session
- VPC endpoints concept introduced but not quizzed

### PromQL & Observability — Not Started
### kubectl Debugging — Not Started
### Behavioral/STAR — Not Started

## Recurring Issues
First session recorded. Pattern from interview: surface-level answers across all topics. Study session shows **significant improvement** on practiced topics — Sai gives specific, correct answers when the concept has been taught interactively. Learning style: needs one concept at a time, hands-on with own code, not info dumps.

## Specific Study Resources
- AWS EKS Best Practices Guide: https://aws.github.io/aws-eks-best-practices/
- Prometheus Querying Basics: https://prometheus.io/docs/prometheus/latest/querying/basics/
- Spring Boot Actuator Metrics: https://docs.spring.io/spring-boot/reference/actuator/metrics.html
- AWS IAM Roles for Service Accounts: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- Kubernetes Pod Security Standards: https://kubernetes.io/docs/concepts/security/pod-security-standards/
