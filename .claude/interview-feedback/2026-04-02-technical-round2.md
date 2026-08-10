---
date: 2026-04-02
round: technical-round2
verdict: BORDERLINE-PASS
score: 6.5/10
comp_120k: Close - Almost Ready
comp_165k: Not Ready
---

# Interview Session: Technical Deep-Dive Round 2 — 2026-04-02

## Market Context
Companies hiring AWS DevOps engineers at $120K-$165K in 2026 continue to focus on EKS operational depth, Terraform at scale, GitOps/Argo workflows, container security, and observability. Real-world scenario questions and the ability to explain trade-offs are increasingly emphasized over rote knowledge. This session tested whether study between rounds translated to interview-quality answers.

## Questions & Evaluation

### Q1: EKS Request Flow (ALB to Pod)
**Question**: Walk me through how a request from the internet reaches your visits-service pod.
**Candidate Answer Summary**: Described ALB, ingress, service routing, pod networking at a reasonable level.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Improved from Round 1 with more structure. Still missing some specifics on VPC CNI, kube-proxy/iptables, and security group layers. Acceptable for $120K, needs more depth for higher comp.

### Q2: Terraform State & Locking
**Question**: Your Terraform state file gets corrupted and a teammate is running apply simultaneously. Walk me through your state management setup and how you handle this.
**Candidate Answer Summary**: Explained S3 backend, `use_lockfile = true` with conditional writes, why DynamoDB is legacy, force-unlock procedure, and recovery steps.
**Rating**: Strong
**Score**: 8/10
**Notes**: Major improvement from Round 1. The study session clearly paid off. Candidate can now explain the WHY behind each choice, not just the WHAT. This answer would pass at most companies.

### Q3: IRSA (IAM Roles for Service Accounts)
**Question**: How does your EKS workload get AWS permissions? Explain the IRSA flow.
**Candidate Answer Summary**: Described the OIDC provider, service account annotation, token injection, and STS exchange at a functional level.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Massive improvement from Round 1 (was Weak/4). The candidate studied IRSA and can now walk through the chain. Not yet Strong — would benefit from mentioning trust policy conditions (namespace/SA scoping) and token refresh mechanics without prompting.

### Q4: Canary Deployment (Argo Rollouts)
**Question**: Describe the full canary deployment flow from image push to 100% traffic.
**Candidate Answer Summary**: Detailed the 3-service pattern, step weights (20/50/80/100), AnalysisTemplate mechanics (count=3, failureLimit=1, success condition), manual vs automatic pause, and rollback behavior.
**Rating**: Strong
**Score**: 8/10
**Notes**: Excellent. This is now a topic the candidate owns. Can explain specific numbers, specific configs, and the reasoning behind each step. This answer would impress interviewers.

### Q5: Pod Security Contexts
**Question**: Your pods run as non-root with read-only rootfs. Explain what each security context field does and why it matters.
**Candidate Answer Summary**: Explained non-root, readOnlyRootFilesystem with emptyDir for /tmp, capability dropping, and the general security rationale.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Improved from Weak in Round 1. Can now explain the key fields. Would be Strong if the candidate also covered seccompProfile: RuntimeDefault (what syscalls it blocks) and connected pod security to compliance frameworks or defense-in-depth.

### Q6: Docker Multi-Stage Builds
**Question**: Explain how multi-stage Docker builds work and why they matter for your project.
**Candidate Answer Summary**: Correctly identified stage 1 = build (code + dependencies), stage 2 = runtime only. Mentioned smaller images are quicker to pull.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Correct core concept. Missing: JDK vs JRE distinction, security benefit (smaller attack surface, no compiler/source code in final image), approximate size numbers (400-500MB vs 200-250MB), connection to canary deployment speed.

## Overall Assessment

This round represents clear, measurable improvement over Round 1. The score moved from 5/10 to 6.5/10, weak answers were eliminated entirely, and two questions earned Strong ratings. The study sessions between rounds are working — topics that were practiced (Terraform state, canary deployments) are now answered at a level that would pass real interviews.

The remaining pattern is consistent: the candidate understands concepts correctly but stops one layer short of the depth that distinguishes a "hire" from a "strong hire." Every Acceptable answer today was correct but incomplete — missing the security angle, the specific number, or the concrete config detail. This is a coachable gap. The candidate needs to build a habit of asking themselves "what is the security implication?" and "what is the specific number/command?" for every topic.

The biggest remaining risk is observability/PromQL, which was the weakest area in Round 1 and has not yet been practiced. This will come up in real interviews and remains a potential rejection point.

## Action Items for Next Session

- [ ] Study: PromQL — this is overdue. Port-forward to Prometheus and run live queries. Memorize `rate()`, `sum by()`, histogram quantiles.
- [ ] Practice: For every concept, add the security implication as a reflex. "Multi-stage builds reduce attack surface." "IRSA scopes credentials to namespace+SA." Make this automatic.
- [ ] Practice: Behavioral/STAR round — technical is approaching threshold, behavioral prep cannot wait.
- [ ] Review: seccompProfile: RuntimeDefault — what syscalls does it block? What happens if your app needs a blocked syscall?
- [ ] Practice: Give approximate numbers for everything — image sizes, latency budgets, cost estimates. Concrete numbers build interviewer confidence.

## Comparison to Round 1

| Metric | Round 1 | Round 2 | Change |
|--------|---------|---------|--------|
| Score | 5/10 | 6.5/10 | +1.5 |
| Strong answers | 0 | 2 | +2 |
| Acceptable answers | 3 | 4 | +1 |
| Weak answers | 3 | 0 | -3 |
| Critical gaps | 0 | 0 | 0 |

## Recurring Issues

**RECURRING ISSUE (seen in 2 sessions):** Answers are conceptually correct but lack the final layer of specificity — security implications, concrete numbers, exact commands/configs. This was the primary feedback in Round 1 and remains the primary feedback in Round 2, though the severity has decreased. This pattern must be broken before real interviews.

**RECURRING ISSUE (seen in 2 sessions):** PromQL/observability has not been practiced. It was flagged as a critical gap in Round 1 and remains unaddressed. This is now the single highest-priority study item.

## Specific Study Resources

- Prometheus Querying Basics: https://prometheus.io/docs/prometheus/latest/querying/basics/
- Spring Boot Actuator Metrics: https://docs.spring.io/spring-boot/reference/actuator/metrics.html
- AWS EKS Pod Security: https://aws.github.io/aws-eks-best-practices/security/docs/pods/
- Docker Multi-Stage Build Docs: https://docs.docker.com/build/building/multi-stage/
- Linux Seccomp Profiles: https://kubernetes.io/docs/tutorials/security/seccomp/
