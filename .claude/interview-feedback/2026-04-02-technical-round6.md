---
date: 2026-04-02
round: technical-round6
verdict: BORDERLINE
score: 5.5/10
comp_120k: Ready
comp_165k: Not Ready - 6-8 weeks
---

# Interview Session: Technical Deep-Dive Round 6 -- 2026-04-02

## Market Context
Companies hiring AWS DevOps engineers at $120K-$165K in 2026 continue to emphasize Kubernetes autoscaling (HPA/VPA), AWS service depth (S3, IAM, CloudWatch), observability frameworks (golden signals, SLI/SLO), and IaC best practices (Helm, Terraform state protection). This round deliberately tested topics the candidate had not yet studied, to expose the boundary between learned knowledge and gaps.

## Questions & Evaluation

### Q1: IAM & Least Privilege
**Question**: Explain the principle of least privilege and how you implement it in your AWS/EKS environment.
**Candidate Answer Summary**: Described the concept of giving minimum permissions needed. Discussed IRSA and ServiceAccount annotations. Covered the general approach but lacked specifics on policy scoping, condition keys, or permission boundaries.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Solid conceptual understanding. Missing: specific IAM policy examples (Resource ARN scoping vs `*`), condition keys (aws:SourceArn, aws:PrincipalTag), permission boundaries for developer guardrails, IAM Access Analyzer for auditing unused permissions. At $120K this passes; at $165K an interviewer expects you to discuss policy refinement workflows.

### Q2: Golden Signals of Monitoring
**Question**: What are the four golden signals of monitoring from Google's SRE book?
**Candidate Answer Summary**: Named three of four: Traffic, Errors, Saturation. Missed Latency.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Getting 3 of 4 shows awareness but missing Latency is notable since it is arguably the most important signal for user-facing services. The four are: **Latency** (request duration), **Traffic** (demand/requests per second), **Errors** (failure rate), **Saturation** (resource fullness). Mnemonic: **L-T-E-S** ("Let's Test Every System"). This is a memorization item -- one review session should lock it in permanently.

### Q3: Blue-Green vs Canary Deployments
**Question**: Compare blue-green and canary deployment strategies. When would you use each?
**Candidate Answer Summary**: Clear explanation of both strategies. Described blue-green as maintaining two identical environments and switching traffic atomically. Described canary as gradual traffic shifting with analysis. Connected canary to the project's Argo Rollouts implementation. Discussed trade-offs: blue-green is simpler but doubles infrastructure cost; canary is more complex but catches issues with partial blast radius.
**Rating**: Strong
**Score**: 8/10
**Notes**: This is a studied topic and it shows. The candidate demonstrated genuine understanding of trade-offs, connected to real project experience, and articulated when each strategy is appropriate. This is what a Strong answer looks like -- the pattern of study-then-master continues.

### Q4: Helm
**Question**: What is Helm and how does it relate to Kubernetes manifest management?
**Candidate Answer Summary**: Described Helm as a package manager for Kubernetes. Mentioned charts, values files, and templating. Understood the general purpose but lacked depth on Helm release management, rollback mechanics, chart repositories, or how Helm interacts with GitOps workflows.
**Rating**: Acceptable
**Score**: 6/10
**Notes**: Functional understanding sufficient for $120K. Missing: `helm install/upgrade/rollback` lifecycle, release history and `helm history`, chart dependencies, values.yaml override hierarchy (chart defaults -> -f override -> --set), Helm vs Kustomize trade-offs, Helm hooks for migrations. The project uses raw manifests rather than Helm, so the lack of hands-on experience is understandable.

### Q5: S3 State File Protection
**Question**: Your Terraform state is in S3. What S3 features protect it from accidental deletion or corruption?
**Candidate Answer Summary**: Mentioned encryption (SSE). Did not cover versioning, MFA delete, lifecycle policies for version retention, bucket policies restricting delete operations, or cross-region replication for disaster recovery.
**Rating**: Weak
**Score**: 3/10
**Notes**: This is a significant gap. S3 is one of the most fundamental AWS services, and protecting critical files like Terraform state is a day-one responsibility. The correct answer includes: (1) **Versioning** -- recover any previous version of the state file. (2) **MFA Delete** -- requires MFA to delete versions or disable versioning (root account only, CLI only). (3) **Bucket policy** -- deny s3:DeleteObject for non-admin principals. (4) **Server-side encryption** (SSE-S3 or SSE-KMS) -- protects data at rest. (5) **Cross-region replication** -- DR protection. (6) **Object Lock** -- WORM compliance. The candidate only mentioned encryption and missed all the deletion-protection mechanisms, which is exactly what the question was asking about.

### Q6: Horizontal Pod Autoscaler (HPA)
**Question**: What is HPA and how would you configure it for your api-gateway service?
**Candidate Answer Summary**: Knew HPA scales pods horizontally but could not describe the configuration (target CPU/memory thresholds, minReplicas, maxReplicas), how metrics-server provides data, or the scaling algorithm. Did not mention VPA or Cluster Autoscaler as complementary tools.
**Rating**: Weak
**Score**: 3/10
**Notes**: HPA is a core Kubernetes concept that appears in nearly every DevOps interview. The correct answer: HPA watches metrics (CPU, memory, custom) via metrics-server and adjusts replica count between min and max. Example config: `minReplicas: 2, maxReplicas: 10, targetCPUUtilizationPercentage: 70`. Key details: stabilization windows prevent flapping (default 5min for scale-down), Cluster Autoscaler adds nodes when HPA wants more pods but no capacity exists, VPA right-sizes individual pods vertically. The candidate's project uses `replicas: 2` statically -- understanding when and how to make that dynamic is expected at any DevOps level.

## Overall Assessment

This round was intentionally designed to push into uncharted territory, and the results confirm what we already suspected: the candidate's study approach works, but the coverage needs to expand. The score dropped from 7.5 (Round 4) to 6 (Round 5) to 5.5 (Round 6) -- not because the candidate is regressing, but because each round introduces more unstudied topics.

The evidence is clear in the data. Blue-green vs canary scored 8/10 -- a topic the candidate has studied extensively. IAM least privilege and Helm scored 6/10 -- topics with partial exposure. S3 protection and HPA scored 3/10 -- topics with no prior study. There is a direct, predictable correlation between study time invested and interview performance. This is actually good news: the candidate has a reliable learning engine; it just needs more fuel.

The critical insight for the candidate is this: at 6 months of experience, having knowledge gaps is expected. What matters is the rate at which you close them. Rounds 1 through 4 proved you can take a topic from Weak to Strong in 1-2 study sessions. The path to $165K is not mysterious -- it is simply applying that same study discipline to the 10-15 topics you have not yet covered.

## Six-Round Progression

| Metric | R1 | R2 | R3 | R4 | R5 | R6 | Trend |
|--------|-----|------|------|------|------|------|-------|
| Score | 5/10 | 6.5/10 | 7/10 | 7.5/10 | 6/10 | 5.5/10 | Peaked on studied topics, dips on new material |
| Strong | 0 | 2 | 2 | 2 | 1 | 1 | Consistent when topic is studied |
| Acceptable | 3 | 4 | 4 | 4 | 3 | 3 | Baseline competence holds |
| Weak | 3 | 0 | 0 | 0 | 2 | 2 | Returns only for unstudied topics |

## Comp Range Assessment

- At $120K: **Ready.** The candidate's studied topics are solidly at or above this bar. The weak answers (S3, HPA) are on topics that a $120K hire would learn on the job within weeks. No interviewer expects encyclopedic knowledge at this level -- they expect learning ability, which this candidate has proven repeatedly.
- At $165K: **Not ready -- needs 6-8 weeks.** The gaps in S3 features, autoscaling, Helm depth, and golden signals are topics a $165K candidate should know cold. The good news: based on the demonstrated study-to-mastery pattern, 6-8 weeks of focused study could close these gaps.

## Action Items for Next Session

- [ ] Study: AWS S3 deep dive -- versioning, MFA delete, lifecycle policies, bucket policies, encryption types (SSE-S3 vs SSE-KMS vs SSE-C), Object Lock, cross-region replication
- [ ] Study: Kubernetes autoscaling -- HPA (config, metrics-server, scaling algorithm, stabilization windows), VPA (modes: Off/Initial/Auto), Cluster Autoscaler, when to combine them
- [ ] Memorize: Golden signals mnemonic L-T-E-S (Latency, Traffic, Errors, Saturation) -- one flash card, done
- [ ] Study: Helm fundamentals -- install/upgrade/rollback lifecycle, values.yaml hierarchy, chart structure, Helm vs Kustomize
- [ ] Review: IAM policy refinement -- Resource ARN scoping, condition keys, IAM Access Analyzer
- [ ] Review: https://sre.google/sre-book/monitoring-distributed-systems/ (golden signals chapter)
- [ ] Review: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/ (HPA docs)
- [ ] Review: https://docs.aws.amazon.com/AmazonS3/latest/userguide/MultiFactorAuthenticationDelete.html (MFA delete)
- [ ] Review: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html (S3 versioning)

## Recurring Issues

**RECURRING ISSUE (seen in 6 sessions): Unstudied topics consistently score Weak (3/10).** This is not a skills problem -- it is a coverage problem. The candidate's learning approach is proven effective (study -> Acceptable -> Strong within 1-2 rounds). The fix is straightforward: make a list of the 15 most-asked DevOps interview topics and systematically study each one. The weak scores will disappear.

**RECURRING ISSUE (seen in 6 sessions): Answers stop one layer short of Strong on partially-studied topics.** IAM and Helm both scored 6/10 -- the candidate knows the concept but not the implementation details. Adding one layer of specificity (actual commands, config snippets, AWS feature names) would push these to 7-8/10.

**PATTERN CONFIRMED (6 sessions): Study -> Master pipeline works reliably.** Canary deployments went from shaky (Round 1) to Strong (Round 3+). Terraform state went from Acceptable to Strong. Shift-left went from Weak (Round 5) to not yet retested but studied. Blue-green scored 8/10 on first test because the candidate had studied it. This pattern is the candidate's greatest asset.

**RESOLVED: DevOps vocabulary.** Shift-left was studied and understood after Round 5 feedback. Blue-green/canary terminology was Strong this round.

**RESOLVED: Cost awareness.** Demonstrated genuine experience since Round 4.
