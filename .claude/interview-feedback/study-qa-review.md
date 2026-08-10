# Study Q&A Review Sheet

Quick-reference of all questions and answers from interview rounds and study sessions. 2-sentence max per answer.

---

## Interview Round 1: 2026-04-02 (Medium Difficulty)

### Q1 — CI/CD: Trivy finds a CRITICAL CVE in your base image but business needs the feature deployed today. What do you do?
A: Check if a patched base image exists — if yes, update and rebuild. If no patch, do a risk assessment with the team, document the CVE, apply available mitigations, and set a remediation timeline.

### Q2 — Terraform: Two engineers run `nowterraform apply` at the same time. What problem does the lock solve, and what if the lock gets stuck?
A: State locking prevents concurrent writes that would corrupt the state file — only one operation can run at a time. If stuck, verify no operation is running, then `terraform force-unlock <LOCK_ID>`.

### Q3 — Networking: Pods in private subnets need to pull images from Docker Hub and talk to the EKS API server. Trace both network paths. Single NAT gateway risk?
A: Docker Hub: pod → node ENI → private route table (0.0.0.0/0) → NAT gateway → public route table → internet gateway → Docker Hub. API server: kubelet → ENI placed by EKS in private subnet → control plane (never leaves VPC). Single NAT gateway = single AZ failure point; acceptable for cost savings in non-prod, use one per AZ in production.

### Q4 — Canary: You push a new image tag. Describe the full flow from push to 100% traffic, including AnalysisTemplate mechanics.
A: Argo Rollouts creates a canary ReplicaSet, shifts 20% traffic via the 3-service pattern, pauses 2m for Prometheus data, runs analysis (success rate >= 95%, 5XX rate <= 1%, checked 3 times with 1 failure allowed), then waits for manual approval before promoting. On failure, all traffic shifts back to the stable ReplicaSet automatically.

### Q5 — IAM/Security: How does IRSA work? Walk through the chain from ServiceAccount to temporary AWS credentials.
A: Skipped during interview. Answer: Pod's ServiceAccount is annotated with a role ARN → EKS injects an OIDC token into the pod → AWS SDK calls STS `AssumeRoleWithWebIdentity` with that token → STS validates it against the OIDC provider → returns temporary credentials (auto-refresh every ~15 min).

### Q6 — Observability: visits-service has 30% error rate at 2 AM. How do you investigate?
A: Check Grafana for HTTP 500 spike with `rate(http_server_requests_seconds_count{service="visits-service",status="500"}[5m])` grouped by pod to isolate if one pod is the problem. Then `kubectl logs <pod>` for stack traces, check `hikaricp_connections_active` for DB pool exhaustion, and `kubectl top pod` for resource pressure.

---

## Session: 2026-04-03 to 2026-04-05

### CVE & Trivy

**Q: If Trivy finds a CRITICAL CVE but `ignore-unfixed: true` is set and there's no patch, does the pipeline fail or pass?**
A: It passes. `ignore-unfixed: true` skips CVEs without an available patch — no point blocking on something you can't fix yet.

**Q: Your Trivy image scan runs AFTER docker push. Is that a problem?**
A: Yes — a vulnerable image reaches Docker Hub before scanning. Fix: split into build (`push: false, load: true`) → scan → push only if clean.

**Q: What would happen if you changed `exit-code: '1'` to `exit-code: '0'`?**
A: Trivy would still report vulnerabilities in the logs but the pipeline would pass regardless. It turns the scan from a gate into a warning.

### Terraform State Locking

**Q: `encrypt = true` in your backend — what does it do, client-side or server-side?**
A: It enables server-side encryption (SSE) — S3 encrypts the state file at rest on the server, not before upload.

**Q: Would adding `dynamodb_table` alongside `use_lockfile = true` be a good idea?**
A: No — it's redundant. `use_lockfile` already handles locking via S3 conditional writes; DynamoDB adds cost and complexity for no benefit.

**Q: Teammate's laptop died mid-apply, state lock is stuck. What's your process?**
A: Verify the operation is truly dead (check timestamp in lock info), then `terraform force-unlock <LOCK_ID>`, then `terraform plan` to check state consistency before doing anything else.

### VPC Networking

**Q: Pod (10.0.1.53) sends a request to RDS (10.0.2.100). Does it go through NAT gateway?**
A: No. Route table matches `10.0.0.0/16 → local` first (most specific match), so traffic stays inside the VPC. NAT is only for `0.0.0.0/0` (external traffic).

**Q: Your kubelet talks to the EKS API server. Does it go through NAT or VPC endpoint?**
A: Neither — EKS places ENIs directly in your private subnets when `endpoint_private_access = true`. Kubelet resolves the API hostname to a private ENI IP and traffic stays inside the VPC.

**Q: You have both private and public API endpoints enabled. Who uses which?**
A: Kubelet uses the private endpoint (ENI in the VPC). Your laptop and GitHub Actions hosted runners use the public endpoint from outside the VPC.

### Canary Deployments (Argo Rollouts)

**Q: What's one thing a Rollout can do that a regular Deployment cannot?**
A: Traffic splitting — sending a specific percentage (e.g., 20%) of traffic to the new version while the old version handles the rest.

**Q: `failureLimit: 1` and `count: 3` — what does that mean?**
A: Run the Prometheus health check 3 times (every 1 minute). If more than 1 of those 3 checks fails, abort the rollout.

**Q: `successCondition: result[0] >= 0.95` — what does 0.95 represent?**
A: 95% or more of requests must be successful (non-5XX). The query divides successful requests by total requests.

**Q: What does `pause: {}` (empty) mean vs `pause: { duration: 30s }`?**
A: Empty pause = wait indefinitely for manual approval. Pause with duration = wait that long then automatically continue.

**Q: How does Kubernetes actually split traffic at `setWeight: 20`?**
A: At the service level using three services: `api-gateway` (root, controls traffic splitting), `api-gateway-stable` (old version), `api-gateway-canary` (new version).

### Pod Security

**Q: `readOnlyRootFilesystem: true` but Spring Boot needs to write to /tmp. How does it work?**
A: An `emptyDir` volume is mounted at `/tmp`, providing a writable directory outside the read-only container filesystem. The app can only write to that one mount point.

**Q: What does `capabilities: drop: ALL` mean?**
A: Strips every Linux capability (NET_RAW, SYS_ADMIN, CHOWN, etc.) from the container. The app doesn't need any root-level powers — it just serves HTTP on port 8080.

### Probes, Resources & Pod Config

**Q: What's the difference between readinessProbe and livenessProbe?**
A: Readiness failure = pod stops receiving traffic but keeps running. Liveness failure = pod gets restarted (killed and recreated).

**Q: There's a memory limit but no CPU limit. Why?**
A: Memory leaks can crash the entire node, so limits contain the blast radius. No CPU limit lets the pod burst and use spare CPU on the node instead of being throttled unnecessarily.

**Q: What is a memory leak?**
A: When an app keeps allocating memory but never releases it (e.g., list that grows forever, unclosed DB connections, cache without eviction). Without a memory limit, one leaky pod can consume all node memory and crash every pod on that node.

**Q: Why `replicas: 2`?**
A: High availability — if one pod crashes, the other keeps serving traffic with zero downtime. Also needed for canary deployments to split traffic between stable and canary pods.

**Q: What does `revisionHistoryLimit: 3` control?**
A: Keeps the 3 most recent old ReplicaSets for rollback and deletes anything older. Without it, old versions pile up and clutter the cluster.

**Q: What do `Always`, `IfNotPresent`, and `Never` imagePullPolicy mean?**
A: `Always` = pull from registry every time. `IfNotPresent` = use cached image if on the node, pull only if missing. `Never` = only use what's already on the node. Using `IfNotPresent` with unique tags (like run ID) is the best combo — always pulls new deploys, caches for restarts.

**Q: Why are Eureka and Config Server disabled in Kubernetes?**
A: Kubernetes provides these natively — ConfigMaps replace Config Server, and Kubernetes DNS-based Service discovery replaces Eureka.

---

## Interview Round 3: 2026-04-02 (Medium-High Difficulty)

### Q1 — Canary: Describe the full canary deployment flow from image push to 100% traffic.
A: GitHub Actions builds image, pushes to Docker Hub, updates deploy.yaml tag. Argo Rollouts creates canary ReplicaSet, shifts 20% traffic via 3-service pattern, runs AnalysisTemplate (3 Prometheus checks, 1 failure allowed, success >= 95%), pauses for manual approval, then steps through 50%/80%/100%. On failure, auto-rollback to stable ReplicaSet.

### Q2 — Terraform: Explain your state management setup and how you handle corruption/simultaneous apply.
A: S3 backend with `use_lockfile = true` uses conditional writes (If-None-Match header) to prevent concurrent applies — no DynamoDB needed. Recovery: verify lock is stale, `terraform force-unlock <LOCK_ID>`, then `terraform plan` to check state consistency.

### Q3 — IRSA: How does your EKS workload get AWS permissions?
A: ServiceAccount annotated with role ARN → EKS injects OIDC token → AWS SDK calls STS AssumeRoleWithWebIdentity → STS validates against OIDC provider → returns temporary credentials. Missing from answer: trust policy conditions scope to specific namespace/SA, token auto-refreshes ~15 min.

### Q4 — CI/CD: Describe your pipeline end to end from git push to production.
A: PR triggers ci.yaml (build, test, SonarCloud, Trivy scan, Docker push, k8s manifest update). Push to main triggers api-gateway-canary.yaml for canary deployment. Separate infra-bootstrap.yaml for Terraform apply. Missing: failure handling specifics, artifact immutability, environment promotion gates.

### Q5 — VPC: Trace the network path for a pod pulling an image from Docker Hub.
A: Pod → node ENI → private subnet route table → 0.0.0.0/0 matches NAT gateway → NAT in public subnet → internet gateway → Docker Hub. Single NAT gateway is cost-effective for non-prod but is a single AZ failure point. Missing: VPC endpoints for ECR/S3 as cost-saving alternative, security group rules at each layer.

### Q6 — Kubernetes: Explain ClusterIP, NodePort, and LoadBalancer service types. Which does your project use?
A: ClusterIP = internal-only access within cluster (used by visits/customers services). NodePort = exposes on node IP. LoadBalancer = provisions cloud LB for external access. API gateway uses Ingress (ALB via AWS LB Controller). Corrections needed: ClusterIP is a virtual IP on the Service (not "identifier for the pod"), NodePort opens port 30000-32767 on every node, Ingress sits on top of a Service (different objects). Cost note: each LoadBalancer = ~$16/month; use path-based routing through single ALB instead.

---

## Interview Round 4: 2026-04-02 (Medium-High Difficulty)

### Q1 — EKS Request Flow: Walk me through how a request from the internet reaches your visits-service pod.
A: Client → Route 53 → ALB (created by AWS LB Controller from Ingress resource) → target group → node → kube-proxy/iptables → ClusterIP Service → pod. Missing: VPC CNI assigns ENI secondary IPs to pods, security group rules at each layer.

### Q2 — Terraform State: Explain your state management and handle corruption/simultaneous apply.
A: S3 backend with `use_lockfile = true` for conditional writes. Recovery: verify lock is stale, `terraform force-unlock`, then plan to verify. Solid knowledge, consistent with previous rounds.

### Q3 — ConfigMaps & Secrets: How do you manage configuration and secrets for your microservices? (STRONG)
A: ConfigMaps for non-sensitive config (application.yaml overrides, environment variables) in each service's configmap.yaml. Secrets for sensitive data (DB credentials). Spring Cloud Config Server centralizes config, ConfigMaps provide environment-specific Kubernetes overrides. Showed real project understanding.

### Q4 — PromQL & Analysis Templates: Explain the PromQL queries in your canary analysis template.
A: Analysis templates query Prometheus to validate canary health — checking success rate and error rate. Understood the concept but could not write specific PromQL from memory (rate(), sum by(), clamp_min()). Improved from Round 1 critical gap but not yet Strong.

### Q5 — Pod Security: Explain what each security context field does and why it matters.
A: Non-root execution (uid 1000), read-only rootfs with emptyDir for /tmp, capability dropping, defense-in-depth. Missing: seccompProfile RuntimeDefault specifics, what capabilities like NET_RAW/SYS_ADMIN do. Consistent Acceptable.

### Q6 — Cost Optimization: Walk through every cost optimization decision and trade-offs. (STRONG)
A: (1) Spot instances — spare capacity, cheaper, risk of interruption. (2) Scale-to-zero at night via GitHub Actions — saves cost, risk of night spikes, production uses hybrid. (3) EKS extended support billing — got charged when version upgraded, built GH Actions to notify of version changes, acknowledged production testing constraint. (4) SNS budget alerts for threshold notifications. Missing: single NAT gateway ($36 vs $107/month), db.t4g.micro, cost_guardrails.tf $20/month budget, specific dollar amounts. But the EKS extended support war story is genuine and impressive.

---

## Interview Round 5: 2026-04-13 (Medium-Hard Difficulty) -- Score: 6/10

### Q1 — Terraform Import: How do you bring a manually-created RDS database under Terraform management?
A: Write the resource block matching existing config → `terraform import aws_db_instance.my_db <rds-instance-identifier>` (maps code to real resource in state, changes nothing in AWS) → `terraform plan` until "No changes." Without import, apply would create a DUPLICATE resource.

### Q2 — ALB vs NLB: What's the difference and when would you use each?
A: ALB = Layer 7 (HTTP-aware), supports path/host routing and weighted target groups. Your project uses ALB because Argo Rollouts needs Layer 7 traffic splitting for canary. NLB = Layer 4 (TCP/UDP), ultra-low latency, static IPs, no HTTP awareness. Use for gaming, gRPC, IoT. Both can be external or internal.

### Q3 — kubectl Debugging: Pod is in CrashLoopBackOff. Walk through your debugging commands.
A: (1) `kubectl get pods -n petclinic` — status, restarts, pod name. (2) `kubectl describe pod <name> -n petclinic` — Events section: OOMKilled? ImagePullBackOff? Failed probe? (3) `kubectl logs <name> --previous -n petclinic` — `--previous` is critical for crashed containers. (4) `kubectl top pod -n petclinic` — memory near limit = OOMKill.

### Q4 — PromQL: Write a query for percentage of successful requests for api-gateway-canary over 5 minutes.
A: `sum(rate(http_server_requests_seconds_count{service="api-gateway-canary",status!~"5.."}[5m])) / sum(rate(http_server_requests_seconds_count{service="api-gateway-canary"}[5m]))`. Key: metric name from Spring Boot Actuator, `!~` for regex NOT match, `rate()` converts counter to per-second, `[5m]` is lookback window, `sum()` aggregates across pods.

### Q5 — RDS Connectivity: How does a pod connect to RDS in a private subnet? What security layers?
A: Same VPC, route table `10.0.0.0/16 → local` — traffic stays internal, no NAT needed. Security layers: (1) EKS node SG outbound on 3306 (allowed by default), (2) RDS SG inbound on 3306 from EKS node SG (key config — denies by default), (3) NACLs (allow all by default), (4) App layer: credentials from K8s Secret, RDS endpoint resolves to private IP.

### Q6 — Shift Left: What does it mean and where do you implement it?
A: Moving testing/security checks earlier in the development lifecycle — catch problems in CI, not production. Your pipeline examples: SonarQube code quality in CI, Trivy FS scan during build, Trivy config scans for K8s/Terraform, Trivy image scan BEFORE docker push. Canary deployment is NOT shift-left — that's a deployment strategy.

---

## Interview Round 6: 2026-04-02 (Medium-Hard Difficulty) -- Score: 5.5/10

### Q1 — IAM & Least Privilege: Explain the principle and how you implement it in AWS/EKS.
A: Give minimum permissions needed for a task. In EKS, use IRSA so pods assume specific IAM roles via ServiceAccount annotations instead of using node-level permissions. Scope IAM policies to specific resources (use ARNs, not `*`). Use condition keys (`aws:SourceArn`, `aws:PrincipalTag`) to further restrict. Use IAM Access Analyzer to find and remove unused permissions. Permission boundaries set maximum permission ceilings for developer-created roles.

### Q2 — Golden Signals: What are the four golden signals of monitoring?
A: From Google's SRE book. Mnemonic: **L-T-E-S** ("Let's Test Every System").
1. **Latency** -- time to service a request (distinguish successful vs failed request latency)
2. **Traffic** -- demand on the system (requests per second)
3. **Errors** -- rate of failed requests (explicit 5XX, implicit like wrong content, policy-based like >1s responses)
4. **Saturation** -- how full your resources are (CPU, memory, disk, connections)

If you can only monitor four things, monitor these four.

### Q3 — Blue-Green vs Canary: Compare the two deployment strategies.
A: **Blue-green**: two identical environments, switch traffic atomically (100% old -> 100% new). Simple, fast rollback (switch back), but doubles infrastructure cost during deployment. Use when you need instant cutover with zero risk tolerance. **Canary**: gradual traffic shift (e.g., 20% -> 50% -> 100%) with health validation at each step. More complex but catches issues with partial blast radius. Use when you want to validate with real production traffic before full rollout. Your project uses canary via Argo Rollouts with Prometheus analysis.

### Q4 — Helm: What is Helm and how does it manage Kubernetes resources?
A: Helm is a package manager for Kubernetes. A **chart** is a bundle of templated K8s manifests. **values.yaml** provides configuration -- override hierarchy: chart defaults -> `-f custom-values.yaml` -> `--set key=value`. Key commands: `helm install` (deploy), `helm upgrade` (update), `helm rollback` (revert to previous release), `helm history` (see release versions). Charts can have dependencies on other charts. Helm vs Kustomize: Helm uses Go templating and packaging; Kustomize uses overlay patching with no templating. Helm hooks run Jobs at lifecycle points (pre-install, post-upgrade) for tasks like DB migrations.

### Q5 — S3 State Protection: What S3 features protect your Terraform state from deletion/corruption?
A: Six layers of protection for critical S3 objects:
1. **Versioning** -- keeps every previous version; recover any past state file with a single click or API call
2. **MFA Delete** -- requires MFA to delete object versions or disable versioning (root account only, CLI only, cannot use console)
3. **Bucket policy** -- deny `s3:DeleteObject` for non-admin principals
4. **Server-side encryption** -- SSE-S3 (AES-256, AWS-managed keys), SSE-KMS (customer-managed KMS key, audit trail via CloudTrail), SSE-C (customer-provided key, you manage rotation)
5. **Cross-region replication** -- disaster recovery, replicate state to another region
6. **Object Lock** -- WORM (Write Once Read Many) compliance, prevents any deletion for a retention period

Important constraint: MFA Delete and lifecycle policies conflict -- you must remove lifecycle config before enabling MFA Delete.

### Q6 — HPA: What is HPA and how would you configure it for your api-gateway?
A: **Horizontal Pod Autoscaler** scales pod count based on observed metrics. Requires **metrics-server** in the cluster. Example config:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```
Key concepts: **stabilization windows** prevent flapping (default 5min scale-down delay). **Cluster Autoscaler** adds nodes when HPA wants pods but no capacity exists. **VPA** (Vertical Pod Autoscaler) right-sizes individual pods -- use VPA for memory, HPA for CPU to avoid conflicts. Three VPA modes: Off (recommendations only), Initial (set at pod creation), Auto (live adjustment with restarts).

---

## Interview Round 7: 2026-04-15 (Medium-Hard) — Score: 7.2/10

### Q1 — Golden Signals (retest): Name all four and map to your project. (STRONG)
A: Latency (`http_server_requests_seconds` histogram — p50/p95/p99), Traffic (request rate via `rate()` over 5m), Errors (5XX ratio from `http_server_requests_seconds_count`), Saturation (pod CPU/memory usage). Mnemonic: L-T-E-S.

### Q2 — HPA (retest): How do you auto-scale pods when CPU is high?
A: Horizontal Pod Autoscaler targets average CPU utilization (e.g., 70%). Needs metrics-server installed and resource requests defined on pods. Set minReplicas/maxReplicas. 5-min stabilization window prevents flapping. Cluster Autoscaler adds nodes if no capacity for new pods.

### Q3 — S3 Recovery (retest): Someone deletes your Terraform state file. How do you recover?
A: S3 versioning — restore the previous version. CLI: `aws s3api list-object-versions` then `aws s3api get-object --version-id`. Prevent recurrence: bucket policy denying DeleteObject, MFA Delete, restrict write access. Without versioning: rebuild state with `terraform import` for every resource.

### Q4 — CloudWatch vs Prometheus: Why Prometheus for your project?
A: Prometheus integrates natively with Argo Rollouts AnalysisTemplates for canary validation. PromQL is powerful, kube-prometheus-stack is K8s community standard, and it's cloud-agnostic. CloudWatch is better for AWS-managed services (RDS, Lambda, ALB), serverless (nothing to manage), logs, and billing alerts. Use both: Prometheus for app metrics, CloudWatch/SNS for cost alerts.

### Q5 — Terraform Modules: Why organize into modules? (STRONG)
A: Reusability (any team can use VPC module with different values), separation of concerns (change networking without touching EKS), readability (root main.tf is clean module calls, not 500+ lines). Also: easier testing and isolated state blast radius.

### Q6 — Containers vs VMs: What's the difference?
A: VMs include full OS + kernel (GBs, minutes to start). Containers share host OS kernel, package only app + dependencies (MBs, seconds to start). Chose containers: 7 microservices on 2 nodes vs 7 EC2 instances. Get K8s orchestration (auto-restart, health checks, canary). Same image runs in dev, CI, and production.

---

## AWS Architecture Session: VPC Deep Dive (2026-04-15) — Score: 5.8/10

### Q1 — NAT Gateway failure causes ImagePullBackOff. Why do existing pods still work? (STRONG)
A: NAT Gateway is down → private subnets can't reach internet → new image pulls fail. Existing pods work because images are cached on the node (`imagePullPolicy: IfNotPresent`). ALB still works because it's in a public subnet with direct IGW route.

### Q2 — Developer can't connect to RDS from laptop. Why?
A: RDS is in a private subnet — no route from the internet exists. Options: VPN, bastion host in public subnet, AWS SSM Session Manager, or `kubectl port-forward` through an existing pod.

### Q3 — Adding 0.0.0.0/0 SG rule to RDS in private subnet. Is it exposed?
A: NO. Private subnet has no IGW route — traffic from internet can't reach RDS regardless of SG rules. Network topology stops traffic before SGs. Still bad practice — remove it for defense in depth and compliance.

### Q4 — Security Groups vs NACLs: Two key differences.
A: (1) SGs are stateful (return traffic auto-allowed), NACLs are stateless (must define both directions). (2) SGs attach to instances/ENIs, NACLs attach to subnets. SGs = allow rules only. NACLs = both allow and deny, evaluated by rule number (lowest first wins).

### Q5 — How to avoid NAT Gateway cost for ECR image pulls?
A: VPC Endpoints. Interface Endpoints for ECR (ecr.api + ecr.dkr, ~$7/mo each) and a free Gateway Endpoint for S3 (image layers). Traffic stays on AWS private network — cheaper, more secure, lower latency.

### Q6 — Three changes to make VPC production-ready.
A: (1) Multi-AZ NAT Gateways — one per AZ for fault tolerance. (2) VPC Endpoints for ECR/S3 — reduce NAT cost, improve security. (3) VPC Flow Logs — network traffic visibility for auditing. Also consider: tighten NACLs, dedicated RDS subnet group, AWS Network Firewall.
