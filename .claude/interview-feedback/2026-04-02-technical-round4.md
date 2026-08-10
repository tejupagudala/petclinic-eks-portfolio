---
date: 2026-04-02
round: technical-round4
verdict: PASS
score: 7.5/10
comp_120k: Ready
comp_165k: Not Ready - 4-6 weeks
---

# Interview Session: Technical Deep-Dive Round 4 -- 2026-04-02

## Market Context
Companies hiring AWS DevOps engineers at $120K-$165K in 2026 are heavily focused on EKS operational depth, Terraform at scale, GitOps/Argo workflows, container security, observability, and cost optimization. Cost awareness has become increasingly important as companies tighten cloud budgets. This session tested six topics with emphasis on depth, trade-offs, and real-world experience.

## Questions & Evaluation

### Q1: EKS Request Flow (ALB to Pod)
**Question**: Walk me through how a request from the internet reaches your visits-service pod.
**Candidate Answer Summary**: Described ALB, ingress, service routing, pod networking. Improved structure from previous rounds.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Consistent Acceptable across rounds. The candidate understands the flow but still misses VPC CNI specifics, kube-proxy/iptables mechanics, and security group layers. This answer would pass at $120K but not impress.

### Q2: Terraform State & Locking
**Question**: Your Terraform state file gets corrupted and a teammate is running apply simultaneously.
**Candidate Answer Summary**: Explained S3 backend, use_lockfile, force-unlock, recovery steps.
**Rating**: Acceptable
**Score**: 7/10
**Notes**: Solid knowledge from study sessions. Rated Acceptable this round rather than Strong because the answer, while correct, lacked the depth shown in earlier dedicated rounds. Still a passable answer.

### Q3: ConfigMaps and Secrets in Kubernetes
**Question**: How do you manage configuration and secrets for your microservices? Explain ConfigMaps vs Secrets and how they are used in your project.
**Candidate Answer Summary**: Clearly distinguished ConfigMaps (non-sensitive config like application.yaml settings, environment variables) from Secrets (sensitive data like DB credentials). Referenced own project's configmap.yaml files for each service. Explained how Spring Cloud Config Server centralizes config and how ConfigMaps feed environment-specific overrides.
**Rating**: Strong
**Score**: 8/10
**Notes**: Excellent answer with project-specific examples. Showed understanding of the Kubernetes config hierarchy and why both ConfigMaps and a config server coexist. Would impress interviewers.

### Q4: PromQL and Analysis Templates
**Question**: Explain the PromQL queries in your canary analysis template. What does each function do?
**Candidate Answer Summary**: Discussed Prometheus integration with canary deployments. Understood that analysis templates query Prometheus to validate canary health. Referenced success rate and error rate metrics.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Improved from the critical gap in Round 1 (3/10) to functional understanding. Still cannot write specific PromQL queries from memory (rate(), sum by(), clamp_min()). Needs one more dedicated practice session to reach Strong.

### Q5: Pod Security Contexts
**Question**: Your pods run as non-root with read-only rootfs. Explain what each security context field does.
**Candidate Answer Summary**: Explained non-root execution, read-only filesystem with emptyDir for /tmp, capability dropping, and the defense-in-depth rationale.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Consistent Acceptable. Still missing seccompProfile: RuntimeDefault explanation (restricts dangerous syscalls like ptrace, mount) and specific capability details (what NET_RAW, SYS_ADMIN do). Correct but incomplete.

### Q6: Cost Optimization
**Question**: Walk me through every cost optimization decision in your infrastructure. What trade-offs did you accept?
**Candidate Answer Summary**: Described four strategies: (1) Spot instances vs on-demand with interruption tradeoff, (2) Scale-to-zero at night via scheduled GitHub Actions with spike risk tradeoff, (3) EKS version extended support billing -- got charged, built GitHub Actions notification to track version changes, acknowledged production testing constraint, (4) SNS budget alerts for billing threshold notifications.
**Rating**: Strong
**Score**: 8/10
**Notes**: Excellent real-experience answer. The EKS extended support billing story is a genuine war story that demonstrates the candidate has been burned by real AWS billing issues and built automation to prevent recurrence. Four strategies with trade-offs for each shows mature cost thinking. Missing: single NAT gateway decision (~$36 vs ~$107/month), db.t4g.micro choice, specific dollar amounts, cost_guardrails.tf $20/month budget with per-service breakdowns. But the real experience compensates.

## Overall Assessment

Round 4 marks a genuine milestone. The candidate has crossed the $120K readiness threshold with a 7.5/10 score, zero Weak answers, and two Strong answers that demonstrate real operational experience. The trajectory from 5/10 to 7.5/10 across four rounds shows that this candidate learns effectively and retains knowledge once studied.

The two Strong answers this round (ConfigMaps and Cost Optimization) represent different strengths: ConfigMaps shows the candidate can explain Kubernetes concepts with project-specific context, while Cost Optimization shows genuine operational experience with real war stories. The EKS extended support billing story is the kind of answer that makes interviewers confident the candidate has actually operated infrastructure, not just deployed it from tutorials.

The remaining Acceptable answers all follow the same pattern: correct understanding, correct high-level explanation, but stopping one layer short of the specificity that would distinguish the candidate at higher comp ranges. This pattern has been present since Round 1 and has improved in severity (no more Weak answers) but not in occurrence. Breaking this pattern is the single highest-leverage improvement for reaching the $165K range.

## Four-Round Comparison

| Metric | Round 1 | Round 2 | Round 3 | Round 4 | Trend |
|--------|---------|---------|---------|---------|-------|
| Score | 5/10 | 6.5/10 | 7/10 | 7.5/10 | Consistent improvement |
| Strong answers | 0 | 2 | 2 | 2 | Studied topics stay mastered |
| Acceptable answers | 3 | 4 | 4 | 4 | Consistent |
| Weak answers | 3 | 0 | 0 | 0 | Eliminated since Round 2 |
| Critical gaps | 0 | 0 | 0 | 0 | None |

## Comp Range Assessment

- At $120K: **Ready.** The candidate can pass phone screens and technical rounds at this level. Strong project, solid fundamentals, real experience stories.
- At $165K: **Not ready -- needs 4-6 more weeks.** Requires deeper architectural thinking, cost estimation from memory, PromQL fluency, and multi-account/multi-region design experience.

## Action Items for Next Session

- [ ] Run: Behavioral/STAR round -- not practiced in any session, represents 30-40% of hiring decision
- [ ] Practice: PromQL hands-on -- port-forward to Prometheus or use online playground. Write analysis-template queries from memory.
- [ ] Practice: "One more layer" reflex -- for top 10 topics, write the one extra sentence that converts Acceptable to Strong
- [ ] Study: Single NAT gateway cost math ($36 vs $107/month), db.t4g.micro specs, cost_guardrails.tf details
- [ ] Action: Start applying to $120K-range positions this week. Real interviews are the best practice.

## Recurring Issues

**RECURRING ISSUE (seen in 4 sessions): Answers stop one layer short of Strong.** Primary feedback across all rounds. Severity has decreased (Weak eliminated, answers are correct) but the pattern persists. The extra sentence of specificity -- a dollar amount, a command, a security implication -- is what separates $120K from $165K candidates.

**RECURRING ISSUE (seen in 4 sessions, improving): PromQL/observability depth.** Was a critical gap in Round 1 (3/10), now Acceptable (6/10). No longer a rejection risk but not yet a strength. One dedicated hands-on session would close this.

**RESOLVED: Cost awareness.** Flagged in Rounds 2-3 as not reflexive. Round 4 Q6 demonstrated genuine, experience-based cost awareness with four strategies and real war stories. Remaining step: weave cost into non-cost questions automatically.

**RESOLVED: Weak answers.** Eliminated since Round 2 and have not returned.

## Specific Study Resources

- AWS EKS Best Practices - Cost Optimization: https://aws.github.io/aws-eks-best-practices/cost_optimization/cost_opt_compute/
- Prometheus Querying Basics: https://prometheus.io/docs/prometheus/latest/querying/basics/
- STAR Method for Behavioral Interviews: https://www.themuse.com/advice/star-interview-method
- AWS NAT Gateway Pricing: https://aws.amazon.com/vpc/pricing/
- Kubernetes ConfigMaps and Secrets: https://kubernetes.io/docs/concepts/configuration/
