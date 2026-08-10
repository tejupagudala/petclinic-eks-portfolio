# kubectl Debugging Cheat Sheet

Interview-focused reference for kubectl debugging on EKS. Built from interview prep sessions covering pod lifecycle, container states, exit codes, probes, and EKS-specific gotchas.

---

## 1. Pod Lifecycle Phases (`status.phase`)

```
Pending → Running → Succeeded
                 ↘ Failed
                 ↘ Unknown
```

| Phase | Meaning |
|-------|---------|
| **Pending** | Pod accepted by cluster, not running yet. Two sub-states: (a) unscheduled — scheduler still looking; (b) scheduled but ContainerCreating — kubelet doing setup |
| **Running** | At least one container created and started. **Probes activate here.** |
| **Succeeded** | All containers exited 0, won't restart (Jobs, CronJobs) |
| **Failed** | All containers terminated, at least one exited non-zero |
| **Unknown** | Kubelet can't report — usually unreachable node |

---

## 2. Container States (separate from pod phase)

Inside a Running pod, each container has its own state:

| State | Meaning | Examples |
|-------|---------|----------|
| **Waiting** | Container hasn't started yet | ContainerCreating, ImagePullBackOff, CrashLoopBackOff |
| **Running** | Container is executing | Probes are active here |
| **Terminated** | Container finished or was killed | Has `Exit Code` and `Reason` |

In `kubectl describe pod`:
```
State:          Waiting
  Reason:       CrashLoopBackOff
Last State:     Terminated         ← what happened previous run
  Reason:       OOMKilled
  Exit Code:    137
```

---

## 3. Lifecycle Order (memorize this)

```
Pending  →  ContainerCreating  →  Running  →  (probes start here)
   ^              ^                   ^
scheduling    kubelet setup       container alive
   |          (image, CNI,
   |           volumes, runtime)
```

**Probes only run AFTER the container is Running.** While in Waiting/ContainerCreating, no probes.

---

## 4. Container Exit Codes

Pattern: `128 + signal number = exit code`.

| Code | Meaning | What to do |
|------|---------|------------|
| **0** | Clean exit but pod restarted | Wrong CMD/ENTRYPOINT in Dockerfile |
| **1** | Generic app error | `kubectl logs --previous` for stack trace |
| **137** | OOMKilled (SIGKILL, signal 9) | Bump memory limit, fix JVM heap |
| **143** | SIGTERM (signal 15, graceful shutdown) | Usually normal; if looping, check liveness probe |

---

## 5. Probe Types

| Probe | Failure Action | Use For |
|-------|----------------|---------|
| **Startup** | Resets startup probe; pauses liveness/readiness | Slow-starting apps (Spring Boot, JVM) |
| **Liveness** | Kills + restarts container | Detect deadlocks, frozen apps |
| **Readiness** | Removes pod from Service endpoints (no restart) | App still warming up, dependency outage |

**Common bug:** `initialDelaySeconds` on liveness too short for Spring Boot → pod loops with exit 143 → CrashLoopBackOff. Fix with a `startupProbe` and generous `failureThreshold`.

---

## 6. requests vs limits

```yaml
resources:
  requests:    # Guaranteed — used by SCHEDULER
    cpu: "250m"
    memory: "256Mi"
  limits:      # Max — enforced by KERNEL at runtime
    cpu: "500m"
    memory: "512Mi"
```

- **Memory exceeds limit** → instant SIGKILL → OOMKilled (137)
- **CPU exceeds limit** → throttled (NOT killed)

### QoS Classes

| Class | Condition | Behavior |
|-------|-----------|----------|
| **Guaranteed** | `requests == limits` for all containers | Last to be evicted |
| **Burstable** | `requests < limits` | Evicted under memory pressure |
| **BestEffort** | No requests OR limits | First to die |

---

## 7. JVM Memory Tuning in Containers

JVMs historically read host memory, not cgroup limits → can OOM in containers.

**Fix (Java 10+):**
```dockerfile
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0"
```
Heap auto-sized to 75% of container limit. Rest goes to non-heap (metaspace, threads, JIT).

**Container memory breakdown:**
```
┌─────────────────────────────┐ ← container limit (512Mi)
│ Native (threads, JNI) ~150  │
│ Metaspace            ~75    │
│ JIT code             ~50    │
│ Heap (-Xmx)          ~250   │ ← 70-75% of limit
└─────────────────────────────┘
```

---

## 8. The Debugging Command Sequence

### CrashLoopBackOff / Pod failures

```bash
# 1. High-level: events, exit codes, probe failures
kubectl describe pod <pod> -n <ns>

# 2. CRITICAL for CrashLoopBackOff — logs from CRASHED container
kubectl logs <pod> -n <ns> --previous

# 3. Current container logs (if running)
kubectl logs <pod> -n <ns>

# 4. Pod manifest (env vars, volumes, image tag)
kubectl get pod <pod> -n <ns> -o yaml

# 5. Specific container in multi-container pod
kubectl logs <pod> -c <container> -n <ns>

# 6. Follow logs in real-time
kubectl logs <pod> -n <ns> -f
```

### ContainerCreating stuck

```bash
# 1. Describe — look at Events section
kubectl describe pod <pod> -n <ns>

# 2. All recent events sorted (great overview)
kubectl get events -n <ns> --sort-by='.lastTimestamp'

# 3. Check node ENI/IP allocation (EKS)
kubectl describe node <node>

# 4. THE answer for EKS IP exhaustion — VPC CNI logs
kubectl logs -n kube-system -l k8s-app=aws-node

# 5. If volumes involved
kubectl get pvc -n <ns>
kubectl describe pvc <pvc> -n <ns>
```

### Pending pod

```bash
# Events tell you why scheduling failed
kubectl describe pod <pod> -n <ns>

# Look for: "0/3 nodes are available: 3 Insufficient memory"
# Or: "node(s) had taint that the pod didn't tolerate"

# Check node capacity
kubectl describe node <node>
kubectl top nodes
```

### Service / Networking issues (pod Running but unreachable)

```bash
# Check if pod is in Service endpoints
kubectl get endpoints <service> -n <ns>

# Check Service config
kubectl get svc <service> -n <ns> -o yaml

# Test connectivity from inside another pod
kubectl exec -it <other-pod> -n <ns> -- curl http://<service>:<port>

# DNS resolution
kubectl exec -it <pod> -n <ns> -- nslookup <service>
```

---

## 9. Common Pod Failure Reasons

| Status / Reason | Category | Likely Cause |
|-----------------|----------|--------------|
| **ImagePullBackOff** | Image | Wrong tag, image doesn't exist, registry down |
| **ErrImagePull** | Image | First pull failure (precedes ImagePullBackOff) |
| **CrashLoopBackOff** | Runtime | App crash, OOM, bad config, probe failing |
| **OOMKilled** (Last State) | Memory | Limit too low, JVM heap too big, leak |
| **Pending + FailedScheduling** | Scheduling | Resources, taints, node selector mismatch |
| **ContainerCreating** stuck | Setup | CNI (IP exhaustion), volume mount, missing Secret |
| **CreateContainerConfigError** | Config | Missing ConfigMap/Secret referenced in env |
| **Evicted** | Node pressure | Disk/memory pressure on node, BestEffort QoS |
| **Completed** + restart | Lifecycle | Wrong CMD/ENTRYPOINT (app exits but K8s expects long-running) |

---

## 10. EKS-Specific: VPC CNI IP Allocation

On EKS, **every pod gets a real VPC IP** from the node's ENIs.

### The hard limit per instance

| Instance | Max ENIs | IPs per ENI | Max Pods (~) |
|----------|----------|-------------|--------------|
| t3.nano | 2 | 2 | 4 |
| **t3.small** | **3** | **4** | **11** |
| t3.medium | 3 | 6 | 17 |
| t3.large | 3 | 12 | 35 |
| m5.large | 3 | 10 | 29 |
| m5.xlarge | 4 | 15 | 58 |

Formula: `Max Pods ≈ (Max ENIs × (IPs per ENI − 1)) + 2`

### Symptoms of IP exhaustion

```
Events:
  Warning  FailedCreatePodSandBox  ...  failed to setup network for sandbox:
    plugin type="aws-cni" failed (add): add cmd: 
    failed to assign an IP address to container
```

VPC CNI logs:
```bash
kubectl logs -n kube-system -l k8s-app=aws-node
# Look for: "no available IP addresses"
```

### Two types of exhaustion

- **Instance-level**: node hit ENI/IP cap → use larger instance or more nodes
- **Subnet-level**: VPC subnet ran out of IPs → larger subnet CIDR or custom networking

### Fixes

- **Larger instance type** — more ENI/IP capacity
- **More nodes** — scale horizontally
- **Prefix delegation** — CNI assigns `/28` blocks (16 IPs at a time):
  ```bash
  kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true
  ```
- **Custom networking** — pods get IPs from a separate, larger subnet

---

## 11. Reading the Events Section

```
Events:
  Type     Reason                  Age              From               Message
  ----     ------                  ----             ----               -------
  Normal   Scheduled               5m               default-scheduler  Successfully assigned ...
  Warning  FailedCreatePodSandBox  4m (x3 over 4m)  kubelet            ... failed to assign an IP address
  Normal   SandboxChanged          2m (x15 over 4m) kubelet            Pod sandbox changed, recreating
```

| Column | Meaning |
|--------|---------|
| **Type** | `Normal` (info) or `Warning` (problem) |
| **Reason** | Short event name — greppable |
| **Age** | `(x3 over 4m)` = happened 3 times in 4 min |
| **From** | Component: scheduler, kubelet, controller-manager |
| **Message** | Human-readable detail |

### Event messages worth recognizing instantly

| Message Snippet | Means |
|-----------------|-------|
| `0/3 nodes are available: 3 Insufficient memory` | Bump down requests, scale, or larger nodes |
| `MountVolume.SetUp failed for volume "x": configmap "y" not found` | ConfigMap missing in namespace |
| `Failed to pull image ... unauthorized` | Registry auth (missing imagePullSecrets / expired ECR token) |
| `Liveness probe failed: HTTP probe failed with statuscode: 503` | App up but health endpoint returning 503 |
| `Back-off restarting failed container` | CrashLoopBackOff — kubelet waits longer each restart |
| `Killing container with id ... Need to kill Pod` | Pod terminating (deploy, scale, eviction) |
| `failed to assign an IP address to container` | EKS VPC CNI IP exhaustion |

---

## 12. stdout / stderr in Containers

- Containers write to **stdout** (normal) and **stderr** (errors)
- Container runtime captures both → writes to `/var/log/pods/<pod>/<container>/0.log`
- `kubectl logs` reads that file — shows **both streams combined** in chronological order
- This is why containers should always log to stdout/stderr (not files inside the container)

---

## 13. Quick Decision Tree

```
Pod not Running?
├── Pending?  → describe pod (Events: scheduling? volume? network?)
├── ContainerCreating stuck?
│       └── kubectl describe + check VPC CNI logs (EKS IP exhaustion?)
├── ImagePullBackOff? → registry / auth / tag issue
├── CrashLoopBackOff?
│       └── kubectl logs --previous + check exit code in describe
│           ├── 137 → OOMKilled (bump memory or fix JVM heap)
│           ├── 143 → SIGTERM (check liveness probe)
│           ├── 1   → app error (read stack trace)
│           └── 0   → wrong CMD/ENTRYPOINT
└── Evicted? → node pressure (kubectl describe node, kubectl top nodes)
```

---

## 14. The Universal Troubleshooting Pattern

**Use this template for ANY troubleshooting interview question.** It's a script you can run in your head under pressure.

### Step 1 — Brainstorm 3 hypotheses (don't pick one yet)
Show the interviewer you can think broadly before narrowing. Senior engineers don't tunnel-vision; juniors guess one thing and chase it.

Example for ImagePullBackOff:
- A: missing imagePullSecret
- B: stale token
- C: image tag doesn't exist

### Step 2 — Confirm with one command per hypothesis
Each command should **eliminate one option**. Shows methodical, evidence-based debugging — not random `kubectl` spam.

- A → `kubectl get secrets -n petclinic`
- B → decode the Secret, check token validity
- C → `gh run view <id>` or `docker pull` manually

### Step 3 — Fix in 3 layers
- **Immediate** ("stop the bleeding") — restore service NOW (e.g., rollback)
- **Root cause** — fix the actual broken thing
- **Long-term** — prevent recurrence (better tooling, alerts, architecture change)

**Why this works:** Shows business sense (uptime first), engineering depth (root cause), and seniority (preventive thinking).

---

## 15. ImagePullBackOff: Docker Hub vs ECR + IRSA

### How Kubernetes pulls private images

There's NO `kubectl login docker.io`. The kubelet uses a **Secret of type `docker-registry`**:

```bash
kubectl create secret docker-registry dockerhub-creds \
  --docker-server=docker.io \
  --docker-username=<user> \
  --docker-password=<token> \
  -n petclinic
```

Then the Deployment must reference it:
```yaml
spec:
  template:
    spec:
      imagePullSecrets:
        - name: dockerhub-creds
```

If the Secret doesn't exist OR isn't referenced OR is in the wrong namespace → pull fails with 401.

### Top 6 causes of ImagePullBackOff (with 401)

1. Missing `imagePullSecrets` on the Deployment
2. Secret exists but has stale token (rotated in registry, not in K8s)
3. Secret in wrong namespace (Secrets are namespace-scoped!)
4. Docker Hub rate limiting (100/6h anonymous, 200/6h auth)
5. Image tag doesn't exist (CI push failed, wrong tag)
6. Repo flipped from public → private

### Confirmation commands

```bash
kubectl get secrets -n petclinic                              # Secret exists?
kubectl get secret dockerhub-creds -n petclinic \
  -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d        # decode contents
kubectl get deployment <name> -n petclinic -o yaml | grep -A2 imagePullSecrets
docker pull docker.io/<user>/<image>:<tag>                    # test from laptop
gh run view <run-id>                                          # did CI push succeed?
```

### Why ECR + IRSA eliminates this whole problem class

**Docker Hub problem:** Long-lived password/token sitting in a Secret. Someone has to remember to rotate it. When it expires → outage.

**ECR + IRSA flow:**
```
Pod starts → uses ServiceAccount → ServiceAccount has IRSA annotation
   → kubelet exchanges projected token for AWS STS credentials
   → kubelet uses those temp creds to call ECR's GetAuthorizationToken
   → ECR returns a 12-hour image pull token automatically
   → image pulls successfully
```

| Docker Hub problem | ECR + IRSA fix |
|--------------------|----------------|
| Token expires → outage | AWS auto-rotates ECR tokens every 12 hours |
| Forgot to update Secret | No Secret needed — IAM handles it |
| Token leaked in logs | No long-lived token to leak |
| Rate limits | No pull rate limits within AWS |
| Network egress to docker.io | Pulls stay inside AWS network (faster, cheaper) |

**Soundbite:** *"ECR + IRSA replaces a long-lived password with short-lived AWS IAM credentials that auto-rotate every 12 hours. There's no Secret to rotate, nothing to expire, and no token to leak."*

---

## 16. `kubectl rollout undo` — The Safe Immediate Fix

K8s keeps a **history of Deployment revisions** (default: last 10). `rollout undo` reverts to the previous one.

### Commands

```bash
# See revision history
kubectl rollout history deployment <name> -n <ns>

# Roll back to immediately previous revision
kubectl rollout undo deployment <name> -n <ns>

# Roll back to a specific revision
kubectl rollout undo deployment <name> -n <ns> --to-revision=5

# Watch the rollback
kubectl rollout status deployment <name> -n <ns>

# Pause/resume an in-progress rollout
kubectl rollout pause deployment <name> -n <ns>
kubectl rollout resume deployment <name> -n <ns>

# Restart all pods (e.g., to pick up new ConfigMap/Secret)
kubectl rollout restart deployment <name> -n <ns>
```

### What happens under the hood

1. Deployment controller swaps the active **ReplicaSet** back to the previous one
2. Old (good) ReplicaSet scales up its pods
3. New (broken) ReplicaSet scales down to 0
4. New pods pull the **previous image tag** — usually already cached on the node

### Why it's the right immediate fix for ImagePullBackOff

- Doesn't touch the broken token/Secret
- Service back online in seconds
- Buys time to fix root cause calmly
- Zero risk — returning to known-good state

**Soundbite:** *"`kubectl rollout undo` swaps the active ReplicaSet back to the previous one — pods that were already healthy come back up. It's the safest immediate fix because you're returning to known-good state."*

---

## 17. Strong-Tier Interview Soundbites

**Pod lifecycle:**
> "Pod phases are Pending, Running, Succeeded, Failed, Unknown. Pending covers both unscheduled and ContainerCreating. Running means a container has been created — that's where probes start. Inside a Running pod, each container has its own state: Waiting, Running, or Terminated. CrashLoopBackOff is a container state, not a pod phase."

**CrashLoopBackOff debugging:**
> "I'd start with `kubectl describe pod` to check Events and Last State — specifically the exit code. 137 = OOMKilled, 143 = SIGTERM, else usually app error. Then `kubectl logs --previous` for the crashed container's stack trace. Remediation depends on findings — bump memory limits, fix liveness probe, or rollback."

**EKS IP exhaustion:**
> "On EKS, the VPC CNI assigns real VPC IPs to pods directly from the node's ENIs. Each EC2 instance type has a hard cap on ENIs and IPs per ENI — for example a t3.small can only run about 11 pods. When you scale past that, pods get stuck in ContainerCreating with FailedCreatePodSandBox events. Fixes include using larger instances, more nodes, or enabling prefix delegation, which lets the CNI assign /28 blocks instead of single IPs."

**JVM in containers:**
> "JVMs in containers need explicit heap sizing because the JVM historically read host memory, not the cgroup limit. Without `-Xmx` or `MaxRAMPercentage`, the JVM can grow beyond the container limit and get OOMKilled. Best practice is `-XX:MaxRAMPercentage=75` so the JVM auto-sizes to 75% of the container limit, leaving headroom for non-heap memory."

**Probes:**
> "Probes need a running process and an open port. While the container is in Waiting (image pull, ContainerCreating), there's nothing to probe. Once the runtime starts the container, the kubelet activates probes. Startup probe runs first if defined, then liveness and readiness."

**Pod failure categories:**
> "I categorize pod failures by lifecycle stage: scheduling failures show up as Pending with FailedScheduling — usually resource or affinity issues. Image failures are ImagePullBackOff — registry, tag, or auth. Runtime failures are CrashLoopBackOff — that's where I go to logs and exit codes. Config failures show up as CreateContainerConfigError — usually a missing Secret or ConfigMap. Eviction usually means node pressure."

**Universal troubleshooting approach:**
> "My troubleshooting framework is: brainstorm 3 hypotheses, confirm each with a single command that eliminates it, then fix in 3 layers — immediate to stop the bleeding, root cause to fix the actual problem, and long-term to prevent recurrence."

**ImagePullBackOff + ECR/IRSA:**
> "ImagePullBackOff with a 401 means kubelet can't authenticate to the registry. Top causes: missing imagePullSecret, stale token after rotation, Secret in wrong namespace, or rate limiting. Immediate fix is `kubectl rollout undo` to restore service, then refresh the Secret. Long-term, I'd migrate to ECR with IRSA — short-lived AWS credentials auto-rotate every 12 hours, eliminating this whole class of bugs."

**rollout undo:**
> "`kubectl rollout undo` swaps the active ReplicaSet back to the previous one — pods that were already healthy come back up. It's the safest immediate fix because you're returning to known-good state."
