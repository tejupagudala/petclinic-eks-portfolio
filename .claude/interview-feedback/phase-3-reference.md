# Phase 3 — Private EKS + Self-Hosted Runner (COMPLETE REFERENCE)

**Window:** Mar 16 → Mar 20, 2026 (~45+ commits, the biggest pre-bootstrap phase)
**Final Average Score:** 7.6/10 across 4 hostile interview questions
**Status:** ✅ Locked — interview-viable

This is your **complete reference** for Phase 3. Everything covered in training is captured here.

---

## 📑 Table of Contents

1. [The Story (Why / What / Fails / Wins)](#the-story)
2. [Architecture Decisions Explained](#architecture-decisions)
3. [The 5 Tracks of Work](#the-5-tracks)
4. [`github_runner.tf` Complete Walkthrough](#github-runner-walkthrough)
5. [Foundation Concepts](#foundation-concepts)
6. [Hostile Q&A (Drilled)](#hostile-qa)
7. [Power Phrases & Secret Weapons](#power-phrases)
8. [Common Mistakes to Avoid](#common-mistakes)
9. [Cheat Card](#cheat-card)

---

<a name="the-story"></a>
## 1. The Story (Why / What / Fails / Wins)

### Why Phase 3 Existed

After Phase 2, your EKS cluster's API endpoint was **publicly accessible**. Even with strict IAM, that's a huge attack surface:
- Brute-force authentication attempts
- Zero-day exploits against the K8s API server (CVE-2018-1002105 history)
- DDoS against the control plane
- Reconnaissance for vulnerable versions

**The fix:** Make the EKS API endpoint **private-only.** Only resources inside your VPC can reach it.

**The problem this created:** GitHub-hosted runners live on the public internet. They can't reach a private EKS endpoint. **Your CI/CD broke the moment you flipped the switch.**

**The solution:** Build your own GitHub Actions runner as an EC2 instance INSIDE your VPC. It can reach EKS via the private endpoint; it can reach GitHub via NAT/public subnet.

**Phase 3 answered three questions simultaneously:**
1. *"How do I reduce the cluster's attack surface?"* → **Private endpoint**
2. *"How do I keep CI/CD working with a private cluster?"* → **Self-hosted runner inside VPC**
3. *"How do I make Helm-based bootstrap reliable?"* → **Preflight checks, concurrency control, timeouts**

### The Fails (Human Story)

| Date | Commit | What broke |
|------|--------|-----------|
| Mar 16 | `de3a36b` | "changed the vpc access to only my ip" — initial IP restriction |
| Mar 17 | `f0cab10` | "wrong path" — Terraform paths in CI |
| Mar 17 | `08dcf4e` | "path error fix" — second attempt |
| Mar 17 | `5a2892f` | "sa not created" — service account creation race |
| Mar 17 | `9bf85db` | "private ip issue" — runner couldn't reach private endpoint |
| Mar 17 | `e9bf71b` | "webhook cert secret missing" — Helm chart needed pre-created secret |
| Mar 17 | `2406193` | "unsupported timeout flags" — Helm CLI version mismatch |
| Mar 17 | `29b0008` | "remove stale release lock" — Helm crashed left a lockfile |
| Mar 17 | `957944a` | "if stuck reinstall helm" — last-resort recovery |
| Mar 20 | `b44c724` | "remove SSM endpoints and fix runner userdata" — VPC endpoint cost rollback |
| Mar 20 | `97bd7b1` | "multi-line error changes" — bash heredoc indentation |
| Mar 20 | `2bd4949` | "oidc issue fix" — IRSA provider URL formatting |

**The honest interview tells:**
- *"I made the EKS API private-only, then immediately broke my CI pipeline because GitHub-hosted runners couldn't reach it anymore. I had to build a self-hosted runner inside the VPC to fix what I'd just broken."*
- *"I tried VPC endpoints for SSM to keep the runner fully internal — then realized 3 interface endpoints would cost $24/month, blowing my $20 budget. I removed them and accepted the runner in a public subnet."*
- *"Helm in CI was the hardest part — 8 commits to handle stale release locks, timeouts, preflight checks. Helm assumes interactive terminal; CI runners aren't interactive."*

### The Wins

By Mar 20, you had:
- ✅ **EKS API endpoint private-only** — public attack surface eliminated
- ✅ **Self-hosted runner on EC2** in the VPC, auto-registering with GitHub
- ✅ **Runner SG locked to your IP** via GitHub Secrets
- ✅ **PAT stored in SSM Parameter Store** as encrypted SecureString
- ✅ **IRSA foundation** laid for ALB Controller (Phase 4)
- ✅ **Helm install reliability** with preflight, concurrency, lockfile cleanup
- ✅ **Documented bootstrap workflow** for future engineers
- ✅ **Cost-aware decisions** documented (VPC endpoints removed, why)

**This is where your project crossed from "can deploy" to "deploys securely from a private cluster."**

---

<a name="architecture-decisions"></a>
## 2. Architecture Decisions Explained

### Why Private EKS Endpoint (Defense in Depth)

Even with strict IAM, network controls catch what IAM doesn't:

| Threat | IAM defense | Network defense |
|---|---|---|
| **DDoS against kube-apiserver** | ❌ Can't help | ✅ Private endpoint = no public reach |
| **K8s API server CVE exploitation** | ❌ Pre-auth bypass possible | ✅ Attackers can't reach to exploit |
| **Reconnaissance** | ❌ /version is public | ✅ Hidden behind private DNS |
| **Stolen credential abuse** | ❌ Valid creds work from anywhere | ✅ Creds only work from inside VPC |

**The Capital One 2019 breach** is the canonical "strict IAM didn't save us" example — credentials exfiltrated via SSRF, used from public internet. Network controls would have made the attack much harder.

### Why Self-Hosted Runner

The constraint cascade:
- Cluster is private → GitHub-hosted runners can't reach it
- Need CI/CD to work → need a runner inside the VPC
- Runner needs to register with GitHub → needs outbound internet
- Runner needs the PAT → needs SSM access
- Runner needs minimal blast radius → tight IAM + IP-locked SG

### Why Public Subnet (Not Private) for the Runner

**Tradeoff evaluated and documented:**
- VPC interface endpoints for SSM = 3 endpoints × $8/mo = $24/mo
- Total budget = $20/mo
- $24 > $20 → endpoints removed
- Accepted: runner in public subnet with restricted SG (only your IP)
- Production: would budget for the endpoints

This is **FinOps maturity** — knew the "right" architecture, evaluated cost, made portfolio-appropriate compromise, documented it.

### Why PAT → Registration Token (The 2-Step Dance)

The PAT is long-lived (months/years until revoked).
The registration token is short-lived (~1 hour).

**Why use the dance:**
- Runner needs to register, but doesn't need to KEEP the PAT
- Use PAT once to get reg token, then forget the PAT
- If runner is compromised post-registration, attacker finds only an expired reg token
- The PAT stays safe in SSM, never on the runner's disk

**Blast radius reduction.**

---

<a name="the-5-tracks"></a>
## 3. The 5 Tracks of Work

### Track 1: Private EKS Endpoint (Mar 20 — `9f794ea`)

In `terraform/modules/eks/main.tf`:

```hcl
vpc_config {
  endpoint_private_access = true       # Private interface endpoint in VPC
  endpoint_public_access  = var.public_endpoint_enabled   # Configurable for bootstrap
  public_access_cidrs     = var.public_access_cidrs
}

encryption_config {
  provider {
    key_arn = aws_kms_key.eks_secrets.arn
  }
  resources = ["secrets"]                # Envelope encryption for K8s secrets
}
```

### Track 2: Self-Hosted GitHub Runner (Mar 17-20 — `cee8425`, `bd7054e`, `6c84a98`, `4c69a9d`)

`terraform/github_runner.tf` (146 lines) provisions:
- EC2 instance (Amazon Linux 2023)
- Security Group (IP-restricted SSH)
- IAM Role + Instance Profile
- SSM Parameter Store SecureString (the PAT)
- User data script (auto-registration)
- GP3 encrypted root volume
- IMDSv2 required
- Tagged `Role: github-self-hosted-runner`

### Track 3: Security — IP Restriction via GitHub Secrets (Mar 20 — `baa5384`, `de3a36b`)

```hcl
dynamic "ingress" {
  for_each = var.github_runner_allowed_ssh_cidrs   # GitHub Secret = IP CIDR
  content {
    description = "Optional SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ingress.value]
  }
}
```

### Track 4: VPC Endpoints — Tried and Removed (Mar 20 — `76656d4`, `b44c724`)

**Cost math:**
- 3 interface endpoints (ssm, ssmmessages, ec2messages) × $8/mo = $24/mo
- Total budget: $20/mo
- Decision: removed, runner stays in public subnet with egress

### Track 5: Operational Tooling Marathon (Mar 17 — 25+ commits)

- kubectl auto-installed via user data
- Kubeconfig generated correctly (multiple iterations)
- EKS auth permissions
- OIDC provider registered for IRSA
- 8 commits on Helm install reliability

---

<a name="github-runner-walkthrough"></a>
## 4. `github_runner.tf` Complete Walkthrough

### Section 1: Local Variables (Lines 1-3)
```hcl
locals {
  github_runner_subnet_id_effective = var.github_runner_subnet_id != "" ? var.github_runner_subnet_id : module.vpc.public_subnet_ids[0]
}
```
Chooses subnet — defaults to public subnet (for internet egress).

### Section 2: AMI Lookup (Lines 5-19)
```hcl
data "aws_ami" "github_runner" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}
```
Latest Amazon Linux 2023 AMI.

### Section 3: SSM Parameter for PAT (Lines 21-29)
```hcl
resource "aws_ssm_parameter" "github_runner_pat" {
  name      = var.github_runner_pat_parameter_name
  type      = "SecureString"        # KMS-encrypted at rest
  value     = var.github_runner_pat
  overwrite = true
}
```
Writes the PAT (from sensitive Terraform variable) to SSM as encrypted SecureString.

### Section 4: Security Group (Lines 31-59)
```hcl
resource "aws_security_group" "github_runner" {
  dynamic "ingress" {              # Only your IP for SSH
    for_each = var.github_runner_allowed_ssh_cidrs
    ...
  }
  egress {                          # Open egress for GitHub + AWS APIs
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### Section 5: IAM Role + Permissions (Lines 61-103)
- EC2 trust policy (can be assumed by ec2.amazonaws.com)
- `AmazonSSMManagedInstanceCore` (for SSM Session Manager)
- Inline policy: `ssm:GetParameter` on the specific PAT parameter ARN ONLY

### Section 6: Instance Profile (Lines 105-109)
```hcl
resource "aws_iam_instance_profile" "github_runner" {
  role = aws_iam_role.github_runner_ec2[0].name
}
```
The wrapper around the IAM role.

### Section 7: EC2 Instance (Lines 111-145)
```hcl
resource "aws_instance" "github_runner" {
  iam_instance_profile = ...
  user_data = templatefile(...)    # Auto-registration script
  
  root_block_device {
    volume_size = ...
    volume_type = "gp3"
    encrypted   = true              # KMS encryption at rest
  }
  
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"      # IMDSv2 ONLY (defends against SSRF)
  }
  
  tags = merge(var.default_tags, {
    Name = "${var.cluster_name}-github-runner"
    Role = "github-self-hosted-runner"   # Used by Phase 2 ABAC policy
  })
}
```

---

<a name="foundation-concepts"></a>
## 5. Foundation Concepts (New in Phase 3)

### Private EKS Endpoint
- `endpoint_private_access = true` — interface endpoint inside VPC
- `endpoint_public_access = var.public_endpoint_enabled` — configurable for bootstrap
- kubectl from inside VPC routes through the private endpoint
- Eliminates public attack surface against kube-apiserver

### Defense in Depth (Network + IAM + RBAC + Audit)
| Layer | Question it answers |
|---|---|
| Network | "Can you reach the API?" (Phase 3) |
| Authentication | "Who are you?" (IAM, OIDC) |
| Authorization | "What can you do?" (Phase 2 IAM + RBAC) |
| Audit | "What did you do?" (CloudTrail + K8s audit logs) |

### Capital One 2019 Breach (real-world reference)
- ModSecurity SSRF + IMDSv1 = credential exfiltration
- 100M customer records leaked, $190M fine
- Used as the canonical "strict IAM alone isn't enough" example

### CVE-2018-1002105 (K8s API server)
- API server proxy let unauthorized users escalate to cluster-admin
- Network-level lockdown would have constrained this CVE
- Example of why network defense matters even with IAM

### Self-Hosted GitHub Runner
- EC2 inside VPC (so it can reach private EKS)
- Polls GitHub for jobs (outbound only)
- Long-lived (not ephemeral) — stays running waiting for jobs
- Auto-registers via user data + PAT + registration token

### IMDSv2 (Instance Metadata Service v2)
- EC2 metadata service at 169.254.169.254
- IMDSv1 = simple GET, vulnerable to SSRF (Capital One)
- IMDSv2 = requires PUT to get session token first, then header on GET
- `http_tokens = required` forces IMDSv2-only
- Most SSRF can't do PUT or custom headers → IMDSv2 breaks the attack

### EBS Volume Encryption
- Default: unencrypted (data on disk in plaintext)
- `encrypted = true` enables KMS encryption at rest
- Required by HIPAA, PCI-DSS, SOC2, GDPR
- Transparent to application (encrypt on write, decrypt on read)
- Protects against snapshot exfiltration, stolen disk, AWS internal access

### ABAC via Role Tag
- Runner tagged `Role=github-self-hosted-runner`
- Phase 2 IAM policy's EC2 Start/Stop Condition: `ec2:ResourceTag/Role = "github-self-hosted-runner"`
- Even with broad Resource (`instance/*`), Condition narrows to ONE instance
- Blast radius: one EC2, not the fleet

### 5-Phase PAT Lifecycle
| Phase | What happens | Where |
|---|---|---|
| 1. Creation | Human creates PAT with `repo` scope on GitHub.com | GitHub UI |
| 2. Storage | Terraform writes to SSM Parameter Store as SecureString | AWS SSM |
| 3. Retrieval | EC2 fetches via IAM role (`ssm:GetParameter`) | EC2 boot, user data |
| 4. Usage | PAT → registration token → register runner. PAT forgotten. | One-time at boot |
| 5. Rotation | New PAT on GitHub → update Terraform var → apply → revoke old | When needed |

### The 2-Step Auth Dance
- Runner uses PAT (long-lived) to call GitHub API
- Gets short-lived registration token (~1 hour)
- Uses registration token to register itself
- Forgets PAT immediately after
- Compromise post-registration = attacker gets expired reg token, not PAT
- **Blast radius limitation**

### SSM Parameter Store SecureString
- AWS-managed encrypted parameter storage
- Default uses AWS-managed KMS key (`aws/ssm`)
- Can specify customer-managed KMS for tighter audit
- IAM-scoped access via `ssm:GetParameter`
- Auto-decryption on read (`--with-decryption`)

### VPC Interface Endpoints (for SSM)
- Provide private network access to AWS APIs
- ~$8/month each + $0.01/GB processed
- For full SSM functionality: ssm + ssmmessages + ec2messages = 3 endpoints
- Total cost: ~$24/month
- FinOps tradeoff: removed for portfolio budget

### Helm-in-CI Pain Pattern
- Helm assumes long-running interactive session
- CI runs are atomic, short-lived
- State model (releases, secrets, lockfiles) doesn't fit CI
- 8 commits of fixes: preflight, concurrency, lockfile cleanup, timeouts
- Modern alternative: Argo CD's Helm support (declarative via GitOps)

### Argo CD Helm Support (Modern Upgrade Path)
- Application CRDs reference Helm charts declaratively
- App-of-Apps pattern: one parent app discovers all child apps
- Argo CD reconciles releases automatically
- Eliminates CI-runner Helm interaction problem
- CI becomes: `kubectl apply -f _root.yaml -n argocd` (once)

---

<a name="hostile-qa"></a>
## 6. Hostile Q&A (Drilled)

Full Q&As with ideal answers, secret weapons, and follow-ups live in **[phase-3-qa.md](phase-3-qa.md)**.

Summary table:

| # | Question | R1 | R2 |
|---|----------|---|---|
| Q1 | Why private EKS endpoint? What did you give up? | **7.5/10** | — |
| Q2 | Walk me through your self-hosted runner end-to-end | (skipped, covered in Q3) | — |
| Q3 | How is your runner authenticated to GitHub? PAT lifecycle? | 6/10 | **8/10** 🔒 |
| Q4 | You added VPC endpoints for SSM then removed them. Why? | **8/10** 🔒 | — |
| Q5 | How does Helm fit into your bootstrap, and why did installs keep failing? | **7/10** | — |

**Phase 3 Average: 7.6/10**

---

<a name="power-phrases"></a>
## 7. Power Phrases & Secret Weapons

### Network Security
- ✨ **"Defense in depth — network perimeter AND identity controls"**
- ✨ **"CVE-2018-1002105 — K8s API server auth bypass"**
- ✨ **"Capital One 2019 breach — strict IAM didn't save them"**
- ✨ **"Private endpoint as the safety net for IAM mistakes"**

### Self-Hosted Runner
- ✨ **"Built the bridge — runner inside VPC bridges public GitHub and private EKS"**
- ✨ **"PAT in SSM Parameter Store SecureString, IMDSv2 required"**
- ✨ **"Long-lived runner, not ephemeral — booting per-job wastes 2 min"**

### IMDSv2
- ✨ **"`http_tokens = required` forces IMDSv2 ONLY"**
- ✨ **"Defends against SSRF — most SSRF can't do PUT or custom headers"**
- ✨ **"The Capital One attack wouldn't work against IMDSv2"**

### EBS Encryption
- ✨ **"GP3 encrypted with KMS — required by HIPAA, PCI, SOC2, GDPR"**
- ✨ **"Transparent encryption — write side encrypts, read side decrypts"**

### PAT Lifecycle
- ✨ **"5-phase PAT lifecycle: creation, storage, retrieval, usage, rotation"**
- ✨ **"2-step auth dance — PAT gets reg token, reg token registers runner"**
- ✨ **"The PAT never lives on the runner's disk past initial registration"**
- ✨ **"Blast radius: post-registration compromise yields expired reg token, not PAT"**
- ✨ **"Modern upgrade path: GitHub Apps with short-lived JWTs"**

### ABAC
- ✨ **"Role tag is what Phase 2's ABAC policy uses to scope"**
- ✨ **"Blast radius is one EC2 instance, not my fleet"**

### FinOps Tradeoff
- ✨ **"Three endpoints: ssm, ssmmessages, ec2messages — $24/mo"**
- ✨ **"Deliberate FinOps tradeoff: cost over isolation for portfolio scope"**
- ✨ **"Commented out as documented production upgrade path"**
- ✨ **"In a regulated production environment — banking, healthcare, defense — I'd budget for those endpoints"**

### Helm + CI
- ✨ **"Helm's state model assumes long-running session where humans can intervene"**
- ✨ **"CI runs are atomic and short-lived; must succeed or fail definitively"**
- ✨ **"8 commits between March 17-20"** (specific pain quantification)
- ✨ **"`--atomic` for auto-rollback on failure"**
- ✨ **"Argo CD's Helm support — declarative via GitOps, eliminates the CI mismatch"**

---

<a name="common-mistakes"></a>
## 8. Common Mistakes to Avoid

| Mistake | Why it hurts |
|---|---|
| Saying *"strict IAM is enough"* | Doesn't address CVE exploitation or DDoS at the network layer |
| Forgetting to mention **Defense in Depth** | The key conceptual framing for this question |
| Conflating Q2 (runner mechanics) with Q3 (PAT lifecycle) | Two different questions; stay focused |
| Saying PAT is used DIRECTLY to register | Wrong — there's a 2-step dance via reg token |
| Saying *"customer KMS"* when default is AWS-managed | Be precise: SSM SecureString uses AWS-managed key unless you specify |
| Forgetting that the runner is LONG-LIVED | It does NOT terminate after each job |
| Calling the EC2 metadata service "IMDS" without specifying v2 | The distinction (v1 vs v2) is the security point |
| Forgetting to cite **Capital One** for IMDSv2 | The breach is the canonical example |
| Saying Helm "needs interactive shell" | Closer to "Helm's state model assumes long-running session" |
| Forgetting the **`--atomic`** Helm flag | The auto-rollback feature is the senior detail |

---

<a name="cheat-card"></a>
## 9. Cheat Card (One-Page Summary)

### Phase 3 Architecture
```
┌────────────────────────────────────────────────────────────┐
│  GitHub.com (public internet)                               │
└────────────────┬───────────────────────────────────────────┘
                 │ runner polls outbound only
                 ↓
┌────────────────────────────────────────────────────────────┐
│  YOUR VPC                                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Public Subnet                                         │  │
│  │  ┌─────────────────────────────┐                       │  │
│  │  │ EC2: Self-Hosted Runner     │                       │  │
│  │  │ • AL2023 + GHA runner v0.25 │                       │  │
│  │  │ • IMDSv2 required           │                       │  │
│  │  │ • GP3 encrypted EBS         │                       │  │
│  │  │ • SG locked to my IP        │                       │  │
│  │  │ • IAM: ssm:GetParameter     │                       │  │
│  │  │ • Tagged Role=runner (ABAC) │                       │  │
│  │  └────────┬──────────┬─────────┘                       │  │
│  └───────────┼──────────┼─────────────────────────────────┘  │
│              │          │                                     │
│         SSM API     EKS Private API                           │
│              ↓          ↓                                     │
│  ┌──────────────┐  ┌──────────────────────────────────────┐  │
│  │ SSM Parameter │  │  Private Subnet                       │  │
│  │ Store         │  │  ┌─────────────────────────────────┐  │  │
│  │ (PAT as       │  │  │ EKS Cluster                      │  │  │
│  │  SecureString)│  │  │ • Private endpoint               │  │  │
│  └──────────────┘  │  │ • KMS-encrypted secrets          │  │  │
│                    │  └─────────────────────────────────┘  │  │
│                    └──────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

### Security Defense Layers
| Layer | What protects | Phase |
|---|---|---|
| Network (private endpoint) | DDoS, CVE exploitation, recon | Phase 3 |
| Authentication (IAM, OIDC) | Who can call APIs | Phase 2 |
| Authorization (IAM scopes + RBAC) | What they can do | Phase 2 |
| Audit (CloudTrail, K8s audit logs) | Forensics | Phase 7 |

### Key Numbers to Remember
- **VPC interface endpoints:** ~$8/month each × 3 SSM endpoints = $24/month
- **Budget:** $20/month (which is why endpoints were removed)
- **Registration token TTL:** ~1 hour
- **EKS reconciliation:** 3 min default (Argo CD polling)
- **Capital One breach (2019):** 100M records, $190M fine
- **Runner is LONG-LIVED:** NOT terminated after each job

### Interview Q Score Targets
| Question Type | Target |
|---|---|
| Why private endpoint | 8+ |
| PAT lifecycle | 8+ |
| VPC endpoints tradeoff | 8+ |
| Helm-in-CI pain | 7+ |

### Universal Phase 3 Answer Framework
1. **State the security/operational concern** (why we did this)
2. **Name the mechanism** (private endpoint, ABAC tag, 2-step dance)
3. **Cite the real-world anchor** (Capital One, CVE, $24/mo math)
4. **State the tradeoff** (what you gave up to gain this)
5. **Senior closer** (production upgrade path, modern alternative)

---

## Phase 3 — COMPLETE ✅

**Average score across 4 questions: 7.6/10 — interview-viable at $120-165K band.**

Next: **Phase 4 — Bootstrap Stabilization Marathon** (Mar 22, the single-day fire-fight — your best fail-story material)
