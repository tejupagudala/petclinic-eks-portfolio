---
date: 2026-04-02
round: technical-round3
verdict: BORDERLINE-PASS
score: 7/10
comp_120k: Close - Nearly Ready
comp_165k: Not Ready
---

# Interview Session: Technical Deep-Dive Round 3 -- 2026-04-02

## Market Context
Companies hiring AWS DevOps engineers at $120K-$165K in 2026 continue to prioritize EKS operational depth, Terraform at scale, GitOps/Argo workflows, Kubernetes networking fundamentals, and CI/CD pipeline design. This session tested breadth across six topics to assess readiness for a real phone screen or technical round, calibrated to current market expectations.

## Questions & Evaluation

### Q1: Canary Deployment Flow (Argo Rollouts)
**Question**: Describe the full canary deployment flow from image push to 100% traffic, including AnalysisTemplate mechanics.
**Candidate Answer Summary**: Detailed the 3-service pattern, step weights (20/50/80/100), AnalysisTemplate mechanics (count=3, failureLimit=1, success condition >= 95%), manual vs automatic pause, and rollback behavior. Referenced specific configs.
**Rating**: Strong
**Score**: 8/10
**Notes**: Second consecutive Strong on this topic. The candidate owns canary deployments -- can explain specific numbers, configs, and reasoning. Interview-ready.

### Q2: Terraform State & Locking
**Question**: Your Terraform state file gets corrupted and a teammate is running apply simultaneously. Walk me through your state management setup and how you handle this.
**Candidate Answer Summary**: Explained S3 backend, use_lockfile = true with conditional writes, why DynamoDB is legacy, force-unlock procedure, and recovery steps.
**Rating**: Strong
**Score**: 8/10
**Notes**: Third session covering this topic, consistently Strong. This is fully internalized knowledge.

### Q3: IRSA (IAM Roles for Service Accounts)
**Question**: How does your EKS workload get AWS permissions? Explain the IRSA flow.
**Candidate Answer Summary**: Described OIDC provider, service account annotation, token injection, STS AssumeRoleWithWebIdentity exchange. Functional understanding of the chain.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Continued improvement from Weak (Round 1) to Acceptable (Rounds 2-3). Still missing trust policy condition specifics (namespace/SA scoping) and token refresh mechanics without prompting. Needs one more push to reach Strong.

### Q4: CI/CD Pipeline (GitHub Actions)
**Question**: Describe your CI/CD pipeline end to end. What happens from git push to production traffic?
**Candidate Answer Summary**: Walked through GitHub Actions stages: build, test, SonarCloud scan, Trivy security scanning, Docker image push, Kubernetes manifest update, canary deployment trigger. Described the separation between CI (ci.yaml) and CD (canary workflow).
**Rating**: Acceptable
**Score**: 7/10
**Notes**: Good end-to-end coverage with understanding of workflow separation. Could improve by mentioning failure handling, artifact immutability, environment promotion gates, and the Trivy scan ordering fix that was implemented in study sessions.

### Q5: VPC & Networking
**Question**: Trace the network path for a pod pulling an image from Docker Hub. Explain subnets, route tables, NAT gateway.
**Candidate Answer Summary**: Described pods in private subnets, NAT gateway for outbound traffic, internet gateway. Understood the general flow and the cost trade-off of single NAT gateway.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Correct general understanding. Missing specifics on route table matching logic (most specific route wins), VPC endpoints as a cost-saving alternative to NAT for AWS services, and security group rules at each layer. This was flagged as a slow-revisit topic in study sessions.

### Q6: Kubernetes Service Types (ClusterIP, NodePort, LoadBalancer)
**Question**: Explain ClusterIP, NodePort, and LoadBalancer service types. Which does your project use and why?
**Candidate Answer Summary**: Correctly identified all three types at concept level. Backend services use ClusterIP for internal communication. API gateway uses Ingress for external access. Mentioned you could switch to LoadBalancer to expose backend services.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Good practical understanding of own project architecture. Terminology corrections needed: ClusterIP is a virtual IP on the Service (not "identifier for the pod"), NodePort opens a specific port (30000-32767) on every node (not "node level access"), Ingress sits on top of a Service (related but different objects). Missing cost awareness -- each LoadBalancer provisions a separate cloud LB (~$16/month); path-based routing through single ALB/Ingress is the cost-efficient approach.

## Overall Assessment

Round 3 confirms the upward trajectory. The candidate has gone from 5/10 with three Weak answers to 7/10 with zero Weak answers and two Strong answers across three sessions. The topics that have been studied (Terraform state, canary deployments) are now fully owned and would pass real interviews. Topics that have been partially studied (IRSA, pod security, CI/CD) are Acceptable -- correct but lacking the final layer of specificity. New topics introduced without prior study (Kubernetes service types, VPC networking details) are answered correctly at the concept level but reveal the same pattern: understanding without precision.

The candidate's learning approach is clearly effective. Interactive study on their own codebase produces Strong answers within one session. The path to interview readiness is to apply this same study method to the remaining Acceptable topics, particularly PromQL/observability which has been deferred since Round 1.

The biggest risk for real interviews is not any single topic -- it is the pattern of stopping one layer short. Every Acceptable answer was correct but incomplete. Training the reflex to add "specifically, that means..." to every explanation would convert multiple Acceptable answers to Strong answers and push the overall score above the $120K threshold.

## Three-Round Comparison

| Metric | Round 1 | Round 2 | Round 3 | Trend |
|--------|---------|---------|---------|-------|
| Score | 5/10 | 6.5/10 | 7/10 | Consistent improvement |
| Strong answers | 0 | 2 | 2 | Holding -- studied topics stick |
| Acceptable answers | 3 | 4 | 4 | Consistent |
| Weak answers | 3 | 0 | 0 | Eliminated since Round 2 |
| Critical gaps | 0 | 0 | 0 | None |

## Comp Range Assessment

- At $120K: Close -- nearly ready. Two more focused sessions should close the gap.
- At $165K: Not ready. Needs deeper architectural thinking, cost awareness as a reflex, and production incident experience.

## Action Items for Next Session

- [ ] Study: PromQL -- NON-NEGOTIABLE. Port-forward to Prometheus, run live queries. Memorize rate(), sum by(), histogram_quantile(). Write analysis-template.yaml queries from memory.
- [ ] Practice: Behavioral/STAR round -- technical is approaching threshold, behavioral prep has not started. This is 30-40% of the hiring decision.
- [ ] Practice: "One more layer" habit -- for every concept, write down the specific detail that turns Acceptable into Strong.
- [ ] Study: Cost estimation for every AWS resource in the stack (ALB ~$16, NAT ~$32, RDS db.t4g.micro ~$12, EKS ~$73).
- [ ] Review: Kubernetes Service types -- ClusterIP is a virtual IP on the Service object, NodePort range is 30000-32767 on every node, Ingress and Service are separate objects.
- [ ] Review: VPC networking -- route table matching (most specific route wins), VPC endpoints for AWS services, security groups at each layer.

## Recurring Issues

**RECURRING ISSUE (seen in 3 sessions): Answers are conceptually correct but stop one layer short of specificity.** This was the primary feedback in Rounds 1, 2, and 3. The severity has decreased (no more Weak answers) but the pattern persists. The candidate says "ClusterIP is for internal access" instead of "ClusterIP is a virtual IP on the Service object, reachable only within the cluster." Training the "specifically, that means..." reflex is the single highest-leverage improvement.

**RECURRING ISSUE (seen in 3 sessions): PromQL/observability has not been practiced.** Flagged as critical in Round 1, flagged again in Round 2, not tested in Round 3. This is the single highest-priority study item and must be addressed before any real interview.

**RECURRING ISSUE (seen in 2 sessions): Cost awareness is not reflexive.** The candidate does not mention cost implications unless asked. At the $120K-$165K range, interviewers expect candidates to raise cost considerations proactively.

## Specific Study Resources

- Kubernetes Services Documentation: https://kubernetes.io/docs/concepts/services-networking/service/
- Prometheus Querying Basics: https://prometheus.io/docs/prometheus/latest/querying/basics/
- AWS VPC Networking: https://docs.aws.amazon.com/vpc/latest/userguide/how-it-works.html
- AWS EKS Best Practices - Cost Optimization: https://aws.github.io/aws-eks-best-practices/cost_optimization/cost_opt_compute/
- STAR Method for Behavioral Interviews: https://www.themuse.com/advice/star-interview-method
