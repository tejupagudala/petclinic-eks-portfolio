# Phase 6 — RDS + Secrets Manager (COMPLETE REFERENCE)

**Window:** Mar 23 → Mar 25, 2026 (~3 days)
**Final Average Score:** **8.0/10** across **5 hostile interview questions** (highest after Phase 4)
**Status:** ✅ Locked — interview-viable at $120-165K band

---

## 📑 Table of Contents

1. [Phase 6 Vocabulary (Memorize These Terms)](#vocabulary)
2. [The Story (Why / What / Fails / Wins)](#the-story)
3. [Architecture Decisions Explained](#architecture-decisions)
4. [The 7-Step Credential Chain](#credential-chain)
5. [Code Walkthrough — `rds.tf` + bootstrap secret-fetch + envFrom](#code-walkthrough)
6. [Foundation Concepts](#foundation-concepts)
7. [5 Hostile Q&A (Drilled — Summaries)](#hostile-qa)
8. [Power Phrases & Secret Weapons](#power-phrases)
9. [Common Mistakes to Avoid](#common-mistakes)
10. [Cheat Card](#cheat-card)

---

<a name="vocabulary"></a>
## 1. Phase 6 Vocabulary (Memorize These Terms)

### RDS Core

| Term | Definition | Where used |
|---|---|---|
| **`aws_db_instance`** | Terraform resource that creates the RDS database | `rds.tf` line 38 |
| **`db.t4g.micro`** | ARM Graviton burstable instance, 2 vCPU burst, 1GB RAM, ~$12/mo | Cheapest managed MySQL |
| **`engine = "mysql"`** | RDS engine choice | MySQL 8.0 |
| **`allocated_storage`** | Initial storage size in GB | 20 GB gp3 |
| **`storage_type = "gp3"`** | General Purpose SSD v3 — cheaper than gp2 for small workloads | `rds.tf` |
| **`storage_encrypted = true`** | Enables encryption at rest via KMS | Required for compliance |
| **`multi_az`** | If true, sync standby in 2nd AZ with auto-failover | `false` for portfolio |
| **`publicly_accessible`** | If false, no public IP assigned | `false` (private only) |
| **`backup_retention_period`** | Days of automated daily snapshots kept | 1 (portfolio); 7-30 (prod) |
| **`skip_final_snapshot`** | If true, no snapshot on destroy | `true` (destroy-friendly) |
| **`deletion_protection`** | Blocks `terraform destroy` if true | `false` (portfolio) |

### Secrets Manager

| Term | Definition | Where used |
|---|---|---|
| **`manage_master_user_password = true`** | ⭐ KEYSTONE — AWS generates pwd, stores in Secrets Manager, no plaintext in Terraform | `rds.tf` line 50 |
| **`master_user_secret`** | Output from `aws_db_instance` exposing the auto-generated secret ARN | Referenced by bootstrap |
| **Secrets Manager secret** | AWS-managed JSON store: `{"username":"admin","password":"..."}` | Auto-created by RDS |
| **`aws secretsmanager get-secret-value`** | CLI command to fetch secret JSON by ARN | Bootstrap workflow step |
| **Rotation (default 7d)** | AWS auto-rotates master password every 7 days | Default schedule |
| **`AWSCURRENT` / `AWSPREVIOUS`** | Staging labels — current password vs prior version | Rotation versioning |

### Network & Encryption

| Term | Definition | Where used |
|---|---|---|
| **`aws_db_subnet_group`** | Tells RDS which subnets it can use (3 private across 3 AZs) | `rds.tf` line 14 |
| **`aws_security_group`** | Firewall — empty by default | `rds.tf` line 21 |
| **`aws_security_group_rule`** | Ingress rule: port 3306 from VPC CIDR only | `rds.tf` line 29 |
| **`aws_kms_key`** | Customer-managed KMS key for RDS encryption | `rds.tf` line 1 |
| **`enable_key_rotation = true`** | AWS rotates key material yearly | `rds.tf` line 4 |
| **`aws_kms_alias`** | Human-readable alias for the KMS key | `rds.tf` line 9 |
| **CMK (Customer-Managed Key)** | KMS key YOU own — full policy control, $1/mo | vs free `aws/rds` |

### Kubernetes Delivery

| Term | Definition | Where used |
|---|---|---|
| **`mysql-credentials` Secret** | K8s Secret in `petclinic` ns mirroring RDS creds | Bootstrap creates |
| **`envFrom: secretRef`** | Pod spec — injects ALL Secret keys as env vars | Each deployment |
| **`env.valueFrom.secretKeyRef`** | Alternative — explicit key mapping | More verbose |
| **`SPRING_DATASOURCE_USERNAME`** | Spring Boot env var → `spring.datasource.username` | Auto-mapped |
| **`SPRING_DATASOURCE_PASSWORD`** | Spring Boot env var → `spring.datasource.password` | Auto-mapped |
| **`SPRING_DATASOURCE_URL`** | JDBC URL with host:port/dbname | Auto-mapped |
| **Spring Boot relaxed binding** | Auto-maps SNAKE_CASE env vars to `dotted.property.names` | Spring magic |
| **HikariCP** | Spring Boot's default JDBC connection pool | Connection mgmt |

### Failure Modes

| Term | Definition |
|---|---|
| **Stale K8s Secret** | K8s Secret holds OLD password after AWS rotation |
| **Delayed failure** | Existing connections survive; break happens at next pod restart |
| **Trigger events** | OOM, eviction, scale, image update, idle timeout |
| **`Access denied for user 'admin'@'...' (using password: YES)`** | Exact MySQL error on stale password |
| **External Secrets Operator (ESO)** | Controller that syncs Secrets Manager → K8s Secret on rotation |
| **Reloader** | Companion controller — restarts pods when Secret hash changes |

---

<a name="the-story"></a>
## 2. The Story (Why / What / Fails / Wins)

### Why Phase 6 Existed

After Phase 5, you had a working CI/CD pipeline deploying stateless Petclinic services to EKS. But Petclinic is fundamentally a **data application** — owners, pets, visits, vets all require persistent storage. You needed:

1. **A real database** — not an in-memory H2 used during tests
2. **Production-grade secrets handling** — no passwords in git, Terraform, or laptops
3. **Network isolation** — DB not exposed to the internet
4. **Cost-efficiency** — RDS layer had to fit in the $20/month total budget

Phase 6 answered: ***"How do I add a managed database with rotating credentials, network-isolated, encrypted, and delivered to pods without ever touching plaintext?"***

The senior answer: **RDS MySQL with `manage_master_user_password = true`, secrets fetched by bootstrap workflow, mirrored into K8s Secret, consumed via `envFrom`.**

### The Fails

| Date | Pain point | Fix |
|---|---|---|
| Mar 23 | First attempt: hardcoded password in `terraform.tfvars` | Removed; added `manage_master_user_password = true` |
| Mar 23 | Bootstrap workflow couldn't read Secrets Manager — IAM permission missing | Added `secretsmanager:GetSecretValue` to runner role |
| Mar 24 | Pods failed with "Access denied" — bootstrap fetched secret BEFORE RDS was fully ready | Added `aws rds wait db-instance-available` before secret fetch |
| Mar 24 | K8s Secret existed but pods didn't pick up — forgot `envFrom` | Added `envFrom: secretRef: name: mysql-credentials` to deployments |
| Mar 25 | Secret creation failed on re-runs ("already exists") | Switched to idempotent `kubectl apply --dry-run=client -o yaml | kubectl apply -f -` pattern |

**Honest interview tells:**
- *"My first version had the password in `terraform.tfvars`. Caught it in the first review — that's plaintext in git. Refactored to use `manage_master_user_password = true` which delegates the entire password lifecycle to AWS."*
- *"I learned the hard way that bootstrap order matters — fetching the secret before RDS is fully available returns an empty value. Added `aws rds wait` to gate the fetch."*

### The Wins

By March 25:
- ✅ RDS MySQL 8.0 on db.t4g.micro, private subnets, encrypted at rest with CMK
- ✅ Master password generated by AWS, stored in Secrets Manager, rotated every 7 days
- ✅ Bootstrap workflow fetches secret via IAM, creates K8s Secret idempotently
- ✅ Petclinic deployments consume Secret via `envFrom` — no app code changes
- ✅ Three-flag destroy-friendly posture (`skip_final_snapshot`, `deletion_protection`, 1-day backup)
- ✅ Total RDS layer cost: ~$15/month — within $20/month total budget
- ⚠️ Rotation gap acknowledged — ESO is the production fix (not wired for portfolio)

---

<a name="architecture-decisions"></a>
## 3. Architecture Decisions Explained

### Why RDS Over In-Cluster MySQL
**Five managed-service wins:**
1. **Backups** — automated snapshots + point-in-time restore vs build CronJobs yourself
2. **Encryption** — one flag (`storage_encrypted = true`) vs PVC + KMS dance
3. **HA** — `multi_az = true` flips a switch vs Galera/Group Replication weeks of work
4. **Patching** — maintenance window vs manual pod rolls
5. **Monitoring** — CloudWatch + Performance Insights free vs build with mysqld_exporter

**The TCO math:** $144/year RDS cost buys 20-40 hours of saved engineering work.

### Why `manage_master_user_password = true`
- No password in Terraform code → no plaintext in git
- No password in tfstate → state file is safe at rest
- AWS handles rotation on default 7-day schedule
- You reference only the ARN, never the value
- **The cost of not doing this:** human-set passwords leak, get reused, never rotate

### Why Customer-Managed KMS ($1/mo) over `aws/rds` (free)
- Key policy control — explicit principals for `kms:Decrypt`
- Compliance frameworks (SOC2, HIPAA, PCI) require CMK
- Key rotation transparency — you see when AWS rotates the key material
- $1/month is rounding error against the compliance signal in your portfolio narrative

### Why Single-AZ ($0 saved vs +$12/mo for multi-AZ)
- Biggest cost saver in your spec
- Tradeoff: ~60-second AZ failover vs 10-20 minute instance replacement
- Portfolio has no real users — "downtime until I notice" is acceptable
- Production trigger: any SLA commitment or compliance audit

### Why 1-Day Backup (Not for Cost Reasons)
- Cost difference between 1-day and 7-day is ~$1/month — trivial
- Real reason: pairs with `skip_final_snapshot = true` + `deletion_protection = false`
- The three-flag destroy combo makes `terraform destroy` painless
- Portfolio gets destroyed/rebuilt frequently → destroy-friendly posture wins

### Why `mysql-credentials` K8s Secret (Not IRSA Direct-to-Secrets-Manager)
- Could pods read Secrets Manager directly via IRSA? Yes — using the AWS SDK + IAM role
- Why the K8s Secret intermediate?
  - **Application doesn't need AWS knowledge** — Spring Boot only knows about env vars
  - **Cloud-portable** — same pod manifest works if you migrate to GCP/Azure
  - **Simpler RBAC** — only the bootstrap runner needs Secrets Manager IAM; pods just need to mount the Secret
- The tradeoff: rotation gap (you fetched once at bootstrap; K8s Secret goes stale)
- Production fix: External Secrets Operator solves the rotation gap while keeping the abstraction

---

<a name="credential-chain"></a>
## 4. The 7-Step Credential Chain

```
1. Terraform `apply`
       │
       │ aws_db_instance with manage_master_user_password = true
       ▼
2. AWS generates random strong password
       │
       │ stores JSON in Secrets Manager: {"username":"admin","password":"..."}
       ▼
3. Bootstrap workflow runs `aws secretsmanager get-secret-value --secret-id <ARN>`
       │
       │ returns JSON
       ▼
4. `jq -r .username` and `jq -r .password` extract fields
       │
       │ bash variables DB_USERNAME and DB_PASSWORD
       ▼
5. `kubectl create secret generic mysql-credentials --dry-run=client -o yaml | kubectl apply -f -`
       │
       │ idempotent: works whether Secret exists or not
       ▼
6. Pod deployments have `envFrom: secretRef: name: mysql-credentials`
       │
       │ all Secret keys injected as env vars
       ▼
7. Spring Boot's relaxed binding maps:
       │ SPRING_DATASOURCE_USERNAME → spring.datasource.username
       │ SPRING_DATASOURCE_PASSWORD → spring.datasource.password
       │ SPRING_DATASOURCE_URL      → spring.datasource.url
       ▼
   HikariCP builds JDBC connection pool → app talks to RDS
```

**The principle:** Secrets Manager owns the truth, K8s Secret is the delivery vehicle, pods read env vars. No password lives in git, Terraform code, tfstate, or pod manifests.

---

<a name="code-walkthrough"></a>
## 5. Code Walkthrough

### File 1: `terraform/rds.tf` (annotated)

```hcl
# KMS Key for RDS encryption at rest
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS storage encryption"
  deletion_window_in_days = 7                # soft-delete window
  enable_key_rotation     = true             # auto-rotate yearly
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.cluster_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# Subnet group — tells RDS which subnets it can use
resource "aws_db_subnet_group" "petclinic" {
  name       = "${var.cluster_name}-rds-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids   # 3 private subnets across 3 AZs
}

# Security Group — empty, rules attached separately
resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Allow MySQL from EKS workloads"
  vpc_id      = module.vpc.vpc_id
}

# SG rule — only port 3306 from VPC CIDR
resource "aws_security_group_rule" "eks_to_rds" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = [var.vpc_cidr]           # 10.0.0.0/16 only
}

# THE KEYSTONE RESOURCE
resource "aws_db_instance" "petclinic" {
  identifier              = "${var.cluster_name}-mysql"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.rds_instance_class   # db.t4g.micro
  allocated_storage       = var.rds_allocated_storage # 20 GB
  storage_type            = "gp3"
  storage_encrypted       = true                     # ⭐ encryption at rest
  kms_key_id              = aws_kms_key.rds.arn      # ⭐ customer-managed key
  db_name                 = "petclinic"

  username                    = var.rds_username
  manage_master_user_password = true                 # ⭐⭐⭐ KEYSTONE FLAG

  db_subnet_group_name    = aws_db_subnet_group.petclinic.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  publicly_accessible     = false                    # ⭐ no public IP
  multi_az                = false                    # cost: single AZ
  backup_retention_period = 1                        # destroy-friendly
  deletion_protection     = false                    # destroy-friendly
  skip_final_snapshot     = true                     # destroy-friendly
}
```

### File 2: Bootstrap workflow secret-fetch step (conceptual)

```bash
# Wait for RDS to be fully ready (avoids race condition)
aws rds wait db-instance-available --db-instance-identifier "${CLUSTER_NAME}-mysql"

# Get the Secrets Manager secret ARN from Terraform output
SECRET_ARN=$(terraform output -raw rds_master_secret_arn)

# Fetch the secret JSON
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_ARN" \
  --query SecretString --output text)

# Extract fields
DB_USERNAME=$(echo "$SECRET_JSON" | jq -r .username)
DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r .password)
DB_HOST=$(terraform output -raw rds_endpoint)

# Create K8s Secret idempotently
kubectl create secret generic mysql-credentials \
  -n petclinic \
  --from-literal=SPRING_DATASOURCE_USERNAME="$DB_USERNAME" \
  --from-literal=SPRING_DATASOURCE_PASSWORD="$DB_PASSWORD" \
  --from-literal=SPRING_DATASOURCE_URL="jdbc:mysql://${DB_HOST}:3306/petclinic" \
  --dry-run=client -o yaml | kubectl apply -f -
```

### File 3: Deployment pod spec (`envFrom` consumption)

```yaml
spec:
  template:
    spec:
      containers:
        - name: customers-service
          image: tejupagudala/spring-petclinic-customers-service:...
          envFrom:
            - secretRef:
                name: mysql-credentials   # injects ALL keys as env vars
          # Spring Boot picks up SPRING_DATASOURCE_USERNAME/PASSWORD/URL
          # and constructs the JDBC DataSource automatically
```

---

<a name="foundation-concepts"></a>
## 6. Foundation Concepts

- **Managed service tradeoff** — pay AWS labor, save your engineering hours
- **`manage_master_user_password = true`** — delegate password lifecycle to AWS
- **Three-layer credential delivery** — Secrets Manager (truth) → K8s Secret (delivery) → pod env vars (consumption)
- **`envFrom: secretRef`** — bulk inject all Secret keys as env vars
- **Spring Boot relaxed binding** — SNAKE_CASE env → dotted.property auto-map
- **HikariCP connection pooling** — connections persist, don't re-auth per query
- **Defense in depth** — VPC + subnets + SG + encryption + auth, each layer assumes prior failure
- **Customer-managed KMS** — key policy control, compliance signal
- **Three-flag destroy combo** — `skip_final_snapshot` + `deletion_protection` + 1-day backup
- **Rotation as security primitive** — bounds blast radius of credential compromise to 7 days
- **Delayed failure mode** — rotation breaks pods at NEXT restart, not immediately
- **External Secrets Operator** — production fix for rotation gap

---

<a name="hostile-qa"></a>
## 7. 5 Hostile Q&A (Drilled — Summaries)

Full Q&As with ideal answers, memory tips, follow-ups live in **[phase-6-qa.md](phase-6-qa.md)**.

| Q | Question | Score | Key insight |
|---|----------|-------|-------------|
| **Q1** | Credential lifecycle | **8.5** (R2) | Secrets Manager → K8s Secret → pod env vars 3-layer chain; `manage_master_user_password = true` keystone |
| **Q2** | Why RDS over in-cluster MySQL? | **7.0** | 5-finger framework: backup/encryption/HA/patching/monitoring; TCO favors managed |
| **Q3** | Network isolation | **8.0** | 5-layer V-S-S-E-A defense; attacker scenario table; defense in depth |
| **Q4** | Cost defense | **8.0** (R2) | 4-decision matrix; 3-flag destroy combo; "stage-appropriate, not permanent" |
| **Q5** | Rotation behavior | **8.5** (R2) | Delayed failure mode; trigger events; 3-step manual recovery; ESO as prod fix |

**Phase 6 Final Average: 8.0/10**

---

<a name="power-phrases"></a>
## 8. Power Phrases & Secret Weapons

### Credential Chain
- ✨ *"Secrets Manager owns the truth, K8s Secret is the delivery vehicle"*
- ✨ *"`manage_master_user_password = true` — AWS generates, I never see the value"*
- ✨ *"No password lives in git, Terraform code, tfstate, or pod manifests"*
- ✨ *"Pods read env vars, not Secrets Manager directly"*

### Managed Service Tradeoff
- ✨ *"Managed service saves engineering hours — pay AWS labor cost, not your own"*
- ✨ *"$144/year buys 20-40 hours of saved ops work — TCO favors RDS heavily"*
- ✨ *"`multi_az = true` is a flag; Galera cluster is weeks of work"*

### Network Security
- ✨ *"Five layers of defense, each requiring an independent compromise"*
- ✨ *"`publicly_accessible = false` means no public IP exists at the routing layer"*
- ✨ *"Defense in depth — each layer assumes the previous one failed"*
- ✨ *"Rotation bounds the blast radius to 7 days"*

### Cost Decisions
- ✨ *"Cost decisions are stage-appropriate, not permanent"*
- ✨ *"Each lever has a specific upgrade signal — not arbitrary"*
- ✨ *"I'd rather increase operational cost than pay on SLA breaches"*
- ✨ *"1-day backup isn't a cost saver — it's a destroy-friendly posture saver"*

### Rotation Failure Mode
- ✨ *"Existing connections survive rotation — MySQL doesn't re-validate mid-session"*
- ✨ *"The break is delayed and silent until a trigger event"*
- ✨ *"By the next rotation, the entire DB-dependent fleet has cycled"*
- ✨ *"ESO triggers rolling restart via deployment annotation hash — fully automatic"*

---

<a name="common-mistakes"></a>
## 9. Common Mistakes to Avoid

| Mistake | Why it hurts |
|---|---|
| Saying "AWS sends the password to the pod" | Wrong — pods read K8s Secret, NOT Secrets Manager |
| Forgetting `manage_master_user_password = true` | This is THE keystone flag — must name it |
| Saying "Secrets Manager rotation just works with my pods" | It doesn't — K8s Secret goes stale; need ESO |
| Confusing `db.t4g.micro` with `t3.micro` | t4g = ARM Graviton; t3 = x86 |
| Saying RDS is in the "public subnet" | It's private subnets only |
| Claiming multi-AZ is on | Your spec is `multi_az = false` |
| Saying multi-AZ = 3 AZs | Multi-AZ = ONE sync standby in 2nd AZ; 3-AZ is Aurora/read replicas |
| Saying "rotation breaks pods immediately" | Wrong — existing connections survive; break at next restart |
| Saying `kubectl argo rollouts restart deployment` | `kubectl argo rollouts` is for Rollout CRDs only; use plain `kubectl rollout restart deployment` |
| Saying "1-day backup is for cost" | Misleading — cost diff is trivial; real reason is destroy-friendliness |

---

<a name="cheat-card"></a>
## 10. Cheat Card (One-Page Summary)

### Phase 6 Architecture
```
[Terraform apply: manage_master_user_password = true]
       ↓
[AWS generates password → Secrets Manager stores JSON → ARN exposed]
       ↓
[Bootstrap: aws secretsmanager get-secret-value]
       ↓
[jq extracts username + password]
       ↓
[kubectl apply mysql-credentials Secret in petclinic ns (idempotent)]
       ↓
[Pod envFrom: secretRef injects SPRING_DATASOURCE_* env vars]
       ↓
[Spring Boot relaxed binding → HikariCP → JDBC → RDS]
```

### The 3-Layer Model
| Layer | Owner | Role |
|---|---|---|
| AWS Secrets Manager | AWS | Truth — auto-generated, auto-rotated |
| K8s Secret `mysql-credentials` | Bootstrap workflow | Delivery vehicle in cluster |
| Pod env vars | Pod spec via `envFrom` | Consumption by Spring Boot |

### The 5-Layer Defense (V-S-S-E-A)
1. **V**PC — private network
2. **S**ubnet — private only, no IGW route
3. **S**ecurity group — port 3306 from VPC CIDR
4. **E**ncryption — KMS at rest, TLS in transit
5. **A**uthentication — password from Secrets Manager

### The 4 Cost Decisions
| Choice | Cost | Production trigger |
|---|---|---|
| `db.t4g.micro` | $12/mo | Sustained CPU > 50%, connection limit |
| `multi_az = false` | $0 saved | Any real SLA, SOC2/PCI |
| 1-day backup | $0.20/mo | Real users with non-replaceable data |
| Customer-managed KMS | $1/mo | Already production-grade |

### The Rotation Failure Timeline
```
T=0:        Rotation; existing connections survive; monitoring green
T+hours:    First pod restart → Access denied → 503s start
T+days:     Cascading as more pods cycle
T+7 days:   Next rotation; full fleet broken
```

### The 3-Step Manual Recovery
1. Re-run bootstrap secret-fetch
2. `kubectl rollout restart deployment -n petclinic`
3. `kubectl get pods` + `kubectl logs` verify

### The Production Fix
**External Secrets Operator** + Reloader:
- ESO watches Secrets Manager, syncs K8s Secret on rotation
- Reloader detects Secret hash change, triggers rolling restart
- Net: zero manual ops on rotation

### Score Targets
| Question Type | Target |
|---|---|
| Credential lifecycle | 8.5+ |
| RDS vs in-cluster | 8+ |
| Network isolation | 8+ |
| Cost defense | 8+ |
| Rotation behavior | 8.5+ |

---

## Phase 6 — COMPLETE ✅

**Average score across 5 questions: 8.0/10 — highest after Phase 4. Interview-locked at $120-165K band.**

Next: **Phase 7 — AIOps Foundation (EKS access + CloudWatch)**
