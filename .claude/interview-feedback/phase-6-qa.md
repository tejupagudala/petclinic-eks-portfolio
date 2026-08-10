# Phase 6 — Q&A Drilled Bank (RDS + Secrets Manager)

**Phase 6 in progress. Q1 LOCKED at 8.5/10 (R2). Q2 locked at 7.0/10. Q3-Q5 pending.**

Companion to `phase-6-reference.md` (pending). This file = hostile Q&As, ideal answers, memory tips, and follow-ups for the RDS + Secrets Manager phase.

---

## Table of Contents

- [Q1: "Walk me through how Petclinic services get RDS credentials"](#q1-credential-lifecycle) — **LOCKED 8.5/10** 🔒
- [Q2: "Why RDS over running MySQL in-cluster on EKS?"](#q2-rds-vs-eks-mysql) — 7.0/10
- [Q3: "Walk me through your RDS network isolation"](#q3-network-isolation) — **LOCKED 8.0/10** 🔒
- [Q4: "Defend your cost decisions — t4g.micro, single-AZ, 1-day backup"](#q4-cost-defense) — **LOCKED 8.0/10** 🔒
- [Q5: "What happens when AWS rotates the master password?"](#q5-rotation-behavior) — **LOCKED 8.5/10** 🔒

---

<a name="q1-credential-lifecycle"></a>
## Q1: "Walk me through how Petclinic services get RDS credentials. Where are they stored, how are they delivered to the pods, and what happens when the password rotates?"

**Round 1 — 2026-06-04 — Score: 5.5/10**
**Round 2 — 2026-06-04 — Score: 8.5/10** 🔒

### R2 Locked Ideal Answer (~120 seconds spoken)

> *"The actual RDS credentials live in Secrets Manager. In `rds.tf`, I have `manage_master_user_password = true` — that flag tells AWS to generate the password and store it in Secrets Manager. I never see the value or write it anywhere.*
>
> *The `infra-bootstrap.yaml` workflow has two steps that bridge AWS to the cluster. Step one runs `aws secretsmanager get-secret-value --secret-id <ARN>` which returns JSON. Step two extracts the username and password fields using `jq` and creates a Kubernetes Secret called `mysql-credentials` in the `petclinic` namespace, using `kubectl apply --dry-run=client -o yaml | kubectl apply -f -` so it's idempotent on re-runs.*
>
> *The Petclinic deployment manifests use `envFrom: secretRef: name: mysql-credentials` which injects every key as environment variables — specifically `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`, and `SPRING_DATASOURCE_URL`. Spring Boot's relaxed binding auto-maps those to `spring.datasource.*` properties and constructs the JDBC connection.*
>
> *No password lives in git, Terraform code, tfstate, or pod manifests.*
>
> *For network defense, RDS is in private subnets — no internet gateway route. As a secondary layer, `publicly_accessible = false` ensures no public IP is assigned even by accident.*
>
> *The honest gap: my current setup fetches once at bootstrap. If AWS rotates the master password on its 7-day default schedule, the K8s Secret goes stale. The production fix is the External Secrets Operator — a controller that watches Secrets Manager and re-syncs the K8s Secret automatically on rotation, then triggers pod restarts via a deployment annotation hash. I haven't wired ESO for portfolio scope but I can talk through the architecture."*

### The 3-Layer Mental Model
```
Secrets Manager  (truth, owned by AWS)
       ↓ bootstrap workflow fetches once
K8s Secret       (delivery vehicle, mysql-credentials in petclinic ns)
       ↓ envFrom injection
Pod env vars     (consumption — SPRING_DATASOURCE_USERNAME/PASSWORD/URL)
       ↓ Spring Boot relaxed binding
JDBC connection  (app connects to RDS)
```

### The 7-Step Credential Chain
1. **Terraform** creates `aws_db_instance` with `manage_master_user_password = true`
2. **AWS generates** random strong password, stores in Secrets Manager, returns ARN
3. **Bootstrap workflow** runs `aws secretsmanager get-secret-value --secret-id <ARN>`
4. **`jq` extracts** username + password from JSON
5. **`kubectl create secret generic`** creates `mysql-credentials` in `petclinic` ns (idempotent via dry-run pipe pattern)
6. **`envFrom: secretRef`** in deployment manifests injects all keys as env vars
7. **Spring Boot** picks up `SPRING_DATASOURCE_*` env vars, builds JDBC DataSource

### Secret Weapon Phrases for Q1
- *"Secrets Manager owns the truth, K8s Secret is the delivery vehicle"*
- *"`manage_master_user_password = true` — AWS generates, I never see the value"*
- *"No password in git, Terraform code, tfstate, or pod manifests"*
- *"Pods read env vars, not Secrets Manager directly"*
- *"The honest gap is rotation — production fix is External Secrets Operator"*

### Likely Hostile Follow-ups for Q1
1. *"What's the difference between `envFrom: secretRef` and `env.valueFrom.secretKeyRef`?"*
2. *"What permissions does the bootstrap runner need to read Secrets Manager?"*
3. *"Why not use IRSA so pods read Secrets Manager directly, bypassing K8s Secret?"*
4. *"What happens to the K8s Secret if someone gets shell on a worker node?"*
5. *"How would you rotate the password manually if AWS rotation broke?"*

---

<a name="q2-rds-vs-eks-mysql"></a>
## Q2: "Why RDS over running MySQL in-cluster on EKS? What did you give up, what did you gain, and when would the other choice be right?"

**Round 1 — 2026-06-04 — Score: 7.0/10**

### What Sai Got Right
- ✅ Named RDS as "fully managed"
- ✅ Listed key managed dimensions: backup, storage, HA
- ✅ Acknowledged MySQL in EKS needs persistent storage (PVC)
- ✅ Listed operational burden: backup, storage, upgrades, recovery
- ✅ Cost framing: "$12/month vs free, but time saved is worth it"
- ✅ Senior closer: "in-cluster MySQL for demos, testing, learning K8s stateful workloads"

### What Costs the 3 Points
- ❌ Didn't mention encryption-at-rest tradeoff (RDS one flag vs PVC + KMS dance)
- ❌ Didn't mention HA specifics (multi_az flag vs Galera/Group Replication)
- ❌ Didn't mention patching / version upgrades (maintenance window vs manual pod roll)
- ❌ Didn't mention monitoring story (CloudWatch free vs mysqld_exporter setup)
- ❌ Didn't quantify the engineering-hours tradeoff ($144/year for 20-40 hours saved ops)
- ❌ "Demos and learning" closer was shallow — missed compliance + region cases
- ⚠️ "Cumbersome" is soft language — better: "operationally expensive" / "high TCO"

### Ideal Answer (~90 seconds spoken)

> *"I evaluated both. RDS is AWS's fully managed relational database — they own the backups, patching, encryption, monitoring, and high availability. In-cluster MySQL on EKS means I run MySQL as a StatefulSet with a persistent volume claim, and I own all of those operational concerns myself.*
>
> *I chose RDS for five specific reasons.*
>
> *First, backups. RDS does daily automated snapshots with point-in-time recovery to any second in the retention window. In EKS I'd build CronJobs running `mysqldump` to S3 and write restore tooling myself.*
>
> *Second, encryption at rest. RDS gives me one flag — `storage_encrypted = true` with a customer-managed KMS key. In EKS I'd configure EBS-encrypted PVCs and manage key policies separately.*
>
> *Third, high availability. RDS Multi-AZ is a flag — AWS provisions a synchronous replica in a second AZ and fails over automatically in about 60 seconds. In EKS I'd build a Galera cluster or MySQL Group Replication, which is weeks of work and significantly more failure modes.*
>
> *Fourth, patching. RDS auto-applies minor version updates during the maintenance window. In EKS I'd pull a new image, roll the StatefulSet pod-by-pod, and handle in-flight connections myself.*
>
> *Fifth, monitoring. RDS gives me CloudWatch metrics and Performance Insights for free. In EKS I'd deploy mysqld_exporter and build the Grafana dashboards myself.*
>
> *The cost tradeoff is $12/month for the t4g.micro instance versus free for in-cluster compute. But that $144/year buys me maybe 20-40 hours of saved engineering work — backups I don't write, upgrades I don't schedule, failovers I don't debug. At any reasonable engineer hourly rate, the TCO favors RDS heavily.*
>
> *When would I run MySQL in EKS instead? Three cases. One — learning or demo environments where ops experience is the goal. Two — strict data residency requirements where the database must live in a specific cluster for compliance. Three — regions where RDS isn't available. For a production-style portfolio, RDS is the deliberate choice."*

### 🧠 Memory Tips for Q2

**The 5-finger framework (memorize):**
1. **Backup** — automated snapshots vs cron + mysqldump
2. **Encryption** — one flag vs PVC + KMS dance
3. **HA** — `multi_az = true` vs Galera/Group Replication
4. **Patching** — maintenance window vs manual pod roll
5. **Monitoring** — CloudWatch free vs mysqld_exporter setup

**The cost reframe (verbatim):**
> *"$144/year buys 20-40 hours of saved engineering work — TCO favors RDS heavily."*

**The reverse-direction closer (3 cases when in-cluster MySQL is right):**
1. **Learning/demos** — ops experience is the goal
2. **Data residency / compliance** — DB must be in-cluster
3. **Region availability** — RDS not in target region

### Secret Weapon Phrases for Q2
- *"Managed service saves engineering hours — pay AWS labor cost, not your own"*
- *"TCO favors RDS — $144/year for 20-40 hours of saved ops work"*
- *"`multi_az = true` is a flag; Galera cluster is weeks of work"*
- *"Maintenance window vs manual pod roll"*
- *"CloudWatch free vs build-it-yourself mysqld_exporter"*
- *"Three cases for in-cluster MySQL: learning, compliance, region gaps"*

### Likely Hostile Follow-ups for Q2

**Q2.F1: "What if RDS goes down? You're locked in to a single managed service."**
> *"Two layers of resilience. First, RDS itself has multi-AZ failover — synchronous replica in a second AZ takes over in ~60 seconds during AZ-level failure. Second, against full RDS service outage, the application would fail. The mitigation is automated snapshots exported to S3 cross-region, plus Terraform IaC that lets me re-provision in a different region in ~20 minutes. Lock-in is real but bounded — my schema and data are portable; the operational tooling around them is what I'd rebuild."*

**Q2.F2: "What about CloudSQL or Aurora — why MySQL on RDS specifically?"**
> *"Three reasons. One — RDS MySQL is the cheapest managed MySQL on AWS at this scale; Aurora starts at db.t4g.medium and minimum costs are ~3x higher. Two — Aurora's storage layer is brilliant for read scaling but I have a single small service that doesn't need it. Three — RDS MySQL keeps me cloud-agnostic in design; if I migrated to GCP CloudSQL or Azure Database for MySQL, my JDBC URL changes and nothing else. Aurora would lock me in. For a startup hitting real read scale, Aurora wins. For Petclinic, RDS MySQL is the right primitive."*

**Q2.F3: "How would you migrate from RDS back to in-cluster MySQL if AWS pricing changed?"**
> *"Three-step migration. One — provision the StatefulSet with persistent volume and matching MySQL 8.0 version in EKS, run schema migrations from RDS dump. Two — use mysqldump or AWS DMS to replicate data; for cutover, take a brief read-only window on RDS, do final sync, flip the K8s Secret's `SPRING_DATASOURCE_URL` to point at the new in-cluster service. Three — rolling restart Petclinic pods to pick up the new URL. Total downtime maybe 5-10 minutes for a portfolio-sized dataset. The Spring Boot side doesn't change — same JDBC driver, same env vars, just a new host in the URL."*

**Q2.F4: "What's the recovery time objective (RTO) for RDS vs in-cluster MySQL?"**
> *"RDS single-AZ — my current setup — has an RTO of about 10-15 minutes for instance replacement, longer for storage corruption requiring snapshot restore. RDS Multi-AZ drops that to ~60 seconds for AZ failover. In-cluster MySQL on EKS depends entirely on what I built: a basic StatefulSet with PVC has RTO measured in pod restart time plus storage attach (~2-3 min), but I'd need to layer on replication and a leader election story to match RDS Multi-AZ's 60s. The honest answer is RDS gives me a better RTO for less engineering work."*

**Q2.F5: "Could you use RDS Proxy to reduce connection overhead from your pods?"**
> *"Yes — RDS Proxy sits between pods and RDS, maintaining a connection pool so each pod doesn't open and tear down its own MySQL connections. For Petclinic with 6 backend services each maintaining HikariCP pools of 10-20 connections, total connections to RDS could approach 120 — close to the t4g.micro's connection limit. RDS Proxy multiplexes those into fewer actual DB connections. Cost is ~$15/month for a small Proxy — for portfolio not worth it; for production with more services or autoscaling, it's standard. I'd add Proxy when connection count becomes the bottleneck."*

---

<a name="q3-network-isolation"></a>
## Q3: "Walk me through your RDS network isolation. How is the database protected from internet exposure, and what would an attacker need to compromise to reach it?"

**Round 1 — 2026-06-04 — Score: 8.0/10** 🔒

### What Sai Got Right
- ✅ Three-layer defense correctly named: VPC → private subnets → security group
- ✅ VPC framing: "private isolated cloud, not accessible from public internet"
- ✅ Private subnets: "no internet gateway route, traffic flows through NAT gateway"
- ✅ Security group: "port 3306 from VPC CIDR only"
- ✅ Threat model walkthrough — 4 attacker scenarios (internet → VPN → pod → worker node)
- ✅ Senior closer: tied rotation back to blast radius limitation (7 days max)
- ✅ Cumulative defense framing: "highly difficult to pass through all stages"

### What Costs the 2 Points
- ⚠️ Minor inaccuracy: said VPN attacker "IP blocked by SG" — once VPN'd into VPC, IP appears as VPC CIDR so SG actually ALLOWS it. Real protection at that point is password requirement, not SG.
- ❌ Didn't mention encryption at rest as a defense layer (KMS-encrypted snapshots unreadable without key)
- ❌ Didn't mention encryption in transit (TLS for pod → RDS connection)
- ❌ Didn't name `aws_security_group_rule` Terraform resource explicitly
- ❌ Could quantify more crisply ("5 layers" vs "3 layers + 2 others scattered")

### Ideal Answer (~110 seconds spoken)

> *"Five layers of defense. Each one independently has to be compromised before the attacker gets data.*
>
> *Layer 1 — VPC isolation. The cluster and RDS sit inside a VPC with a 10.0.0.0/16 CIDR block. The VPC is a private network — nothing inside it is reachable from the public internet by default.*
>
> *Layer 2 — Subnet placement. RDS lives in private subnets only — defined via `aws_db_subnet_group`. Private subnets have no route to the internet gateway, only to the NAT gateway for outbound. Inbound from the internet is impossible at the routing level.*
>
> *Layer 3 — Security group. The `aws_security_group_rule` allows ingress only on port 3306 from the VPC CIDR. Any other port, any source outside VPC — denied at the firewall.*
>
> *Layer 4 — Encryption at rest. `storage_encrypted = true` with my customer-managed KMS key. Even if an attacker exfiltrated a snapshot, the data is unreadable without the KMS key, which has its own IAM policy.*
>
> *Layer 5 — Application authentication. The MySQL master password lives in Secrets Manager, mirrored into a K8s Secret. Reaching RDS over the network doesn't grant access — you need the password.*
>
> *Attacker progression — what they'd need to compromise.*
>
> *Internet attacker — blocked at routing layer. `publicly_accessible = false` means no public IP exists.*
>
> *VPN-compromised attacker — gets inside VPC, SG no longer protects them. But they need the database password from the K8s Secret.*
>
> *Pod-compromised attacker — can reach RDS on 3306. Still needs the password. Currently in the K8s Secret, also reachable from the same pod if they have RBAC.*
>
> *Worker node shell — can read K8s Secrets from etcd. Now has the password. But AWS rotates the master password every 7 days on default schedule, so the blast radius is bounded to 7 days.*
>
> *KMS key compromise — only with that AND the snapshot do they get historical data. Two independent compromises required.*
>
> *Defense in depth — each layer assumes the previous one failed. The job is bounding the blast radius and forcing the attacker to compromise multiple independent systems."*

### 🧠 Memory Tips for Q3

**The 5-layer mnemonic: V-S-S-E-A**
1. **V**PC — private network
2. **S**ubnet — private only, no IGW route
3. **S**ecurity group — 3306 from VPC CIDR only
4. **E**ncryption — at rest (KMS) + in transit (TLS)
5. **A**uthentication — password from Secrets Manager

**The attacker scenario table (memorize):**
| Scenario | Blocked by | What they'd still need |
|---|---|---|
| Internet | `publicly_accessible = false` | — fully blocked |
| VPN compromise | nothing — VPN bypasses SG | Database password |
| Pod compromise | nothing — can reach RDS | Database password |
| Worker node shell | nothing — can read K8s Secret | Bounded by 7-day rotation |
| Snapshot exfiltration | KMS encryption | KMS key access |

**The principle (verbatim):**
> *"Defense in depth — each layer assumes the previous one failed. The job is bounding the blast radius and forcing multiple independent compromises."*

### Secret Weapon Phrases for Q3
- *"Five layers of defense, each requiring an independent compromise"*
- *"`publicly_accessible = false` means no public IP exists at the routing layer"*
- *"Private subnets have no internet gateway route — inbound from internet is impossible"*
- *"`aws_security_group_rule` allows 3306 from VPC CIDR only"*
- *"Even an exfiltrated snapshot is useless without the KMS key"*
- *"Defense in depth — each layer assumes the previous one failed"*
- *"Rotation bounds the blast radius to 7 days"*

### Likely Hostile Follow-ups for Q3

**Q3.F1: "What if the SG rule was misconfigured to allow 0.0.0.0/0 on 3306?"**
> *"That would expose RDS to anywhere a route exists — but `publicly_accessible = false` still keeps it off the public internet because there's no public IP. The exposure would be VPC-wide instead of source-restricted. Mitigation is preventive: I'd add an `aws_config_rule` to flag any SG rule with 0.0.0.0/0 on database ports, plus a Terraform validation block on the source CIDR. Detection layer: AWS Config + Security Hub findings would alert me. The real problem with that misconfig isn't internet exposure — it's that any compromised resource anywhere in the VPC can talk to RDS instead of just my EKS pods."*

**Q3.F2: "How would you detect an active intrusion attempt against RDS?"**
> *"Three signals. One — RDS Performance Insights or CloudWatch metrics show unusual connection patterns: spike in failed authentications, connections from unexpected source IPs in VPC Flow Logs, or query patterns inconsistent with Petclinic's normal traffic. Two — VPC Flow Logs to CloudWatch with a metric filter on REJECT events to the RDS ENI. Three — RDS database audit logging via the `MariaDB Audit Plugin` for MySQL would log every connection attempt and query. Alert on auth failure spikes via CloudWatch alarm to SNS to PagerDuty. For my portfolio I have CloudWatch metrics but not the audit log pipeline — that's the production gap."*

**Q3.F3: "VPC Flow Logs — do you have them enabled?"**
> *"Not in my current Terraform. Honest gap. The fix is one resource block: `aws_flow_log` with log_destination_type CloudWatch or S3, traffic_type ALL, attached to the VPC. Cost is ~$0.50/GB ingested — for a small portfolio cluster, maybe $1-2/month. Production-grade observability requires Flow Logs because without them you have zero visibility into network-level intrusion attempts or unexpected egress. I'd add them as Phase 6.5 work."*

**Q3.F4: "What's the IAM policy on your KMS key? Who can decrypt?"**
> *"The KMS key is created in `rds.tf` with `enable_key_rotation = true` and a 7-day deletion window. By default, the key policy grants root account access. I'd extend it to explicitly grant `kms:Decrypt` to two principals only: the RDS service principal so RDS itself can read encrypted storage, and the IAM role used by my infra runner for snapshot operations. Application pods don't need direct KMS access because RDS decrypts on read transparently. The least-privilege principle: KMS access list should be auditable in 10 seconds and surprise nobody."*

**Q3.F5: "How would you respond if you suspected a password compromise?"**
> *"Five-step incident response. One — immediately rotate the master password manually via `aws secretsmanager rotate-secret` or by triggering a new RDS-managed rotation. Two — re-run my bootstrap workflow to refresh the K8s Secret with the new password, and rolling-restart Petclinic pods to pick it up. Three — review CloudWatch Logs and any DB audit logs for the window when the old password was valid, looking for unfamiliar query patterns or data exfiltration size. Four — check VPC Flow Logs for unexpected egress from RDS or from worker nodes during the suspect window. Five — post-incident, accelerate the External Secrets Operator work so future rotations are automatic, and tighten K8s RBAC so fewer ServiceAccounts can read the `mysql-credentials` Secret."*

---

<a name="q4-cost-defense"></a>
## Q4: "Defend your cost decisions on RDS — `db.t4g.micro`, `multi_az = false`, 1-day backup retention, customer-managed KMS. What did you give up, why acceptable, and what triggers a production upgrade?"

**Round 1 — 2026-06-04 — Score: 6.5/10**
**Round 2 — 2026-06-04 — Score: 8.0/10** 🔒

### R2 Improvements Sai Applied
- ✅ Specific cost numbers for each upgrade (t4g.small ~$24, multi-AZ ~$24-36, 7-day backup ~$1.20)
- ✅ Named the destroy-friendly flag pair: `skip_final_snapshot = true` + `deletion_protection = false`
- ✅ Tied production triggers to scenarios (real users, no-data-loss, performance)
- ✅ Recognized 1-day backup cost is trivial — real reason is destroy posture, not money
- ✅ KILLER closer: *"I'd rather increase operational cost than pay on SLA breaches which will cost me more"*
- ✅ Customer-managed KMS justification with full control framing

### Remaining Polish for 9+
- ⚠️ Multi-AZ math: provisions ONE synchronous standby (doubles cost), not 3-AZ active (that's Aurora/read replicas)
- ⚠️ Backup framing could be cleaner: "1-day vs 7-day is ~$1/month — trivial. Real reason is destroy-friendly posture."
- ❌ Didn't say verbatim "stage-appropriate, not permanent"
- ❌ Didn't quantify TOTAL cost saved (~$30-40/mo gap between portfolio and production)

### R2 Locked Ideal Answer (~120 seconds spoken)

> *"Every cost decision was deliberate against a $20/month total budget — RDS alone is ~$15 of that, so I optimized hard.*
>
> *Instance class — `db.t4g.micro` at ~$12/month. In production I'd use t4g.small at ~$24/month — doubles cost for better sustained CPU and memory headroom. Upgrade trigger: connection count near limit or sustained CPU above 50%.*
>
> *Multi-AZ — disabled. Biggest single saver in my spec. `multi_az = true` provisions a synchronous standby in a second AZ and doubles my $12/month to $24/month. What I gave up: ~60-second AZ failover. With single-AZ, an AZ outage takes me down until AWS replaces the instance — could be 10-20 minutes. Acceptable because portfolio has no real users. Upgrade trigger: any real SLA commitment or SOC2/PCI compliance.*
>
> *Backup retention — 1 day. The cost difference between 1 and 7 days is trivial — roughly $0.20 vs $1.20 per month. The real reason I chose 1-day isn't cost — it's pairing with `skip_final_snapshot = true` and `deletion_protection = false`. Those three flags together make `terraform destroy` painless, leaving no traces. My portfolio gets torn down and rebuilt frequently. Upgrade trigger: as soon as real users store data I can't lose — flip all three flags for 7-day retention with final snapshot and deletion protection on.*
>
> *KMS — customer-managed at $1/month. AWS-managed `aws/rds` would be free. I kept customer-managed for the compliance posture — full key policy control, key rotation transparency, signal for interview narrative. Upgrade trigger: already at production-grade for this lever.*
>
> *The principle: cost decisions are stage-appropriate, not permanent. Each lever has a specific upgrade signal. I'd rather increase operational cost in production than pay on SLA breaches that would cost more in damage."*

### 🧠 Memory Tips for Q4

**The 4-decision defense matrix (memorize):**
| Choice | Portfolio cost | Production cost | What I gave up | Trigger to upgrade |
|---|---|---|---|---|
| `db.t4g.micro` | $12/mo | $24+/mo (small/medium) | Sustained CPU, connection ceiling | Connection count near limit, CPU > 50% sustained |
| `multi_az = false` | $0 saved | +$12/mo (doubles) | ~60s AZ failover | Real SLA commitment, SOC2/PCI |
| 1-day backup | ~$0.20/mo | ~$1.20/mo | 6 days of point-in-time history | Real data that can't be lost |
| Customer-managed KMS | $1/mo | $1/mo | (nothing — kept for narrative) | Already production-grade |

**The 3-flag destroy combo (memorize):**
> *"`backup_retention_period = 1` + `skip_final_snapshot = true` + `deletion_protection = false` — three flags that make `terraform destroy` painless. The portfolio cost saver is destroy-friendliness, not storage."*

**The senior closer (verbatim):**
> *"Cost decisions are stage-appropriate, not permanent. Each lever has a specific upgrade signal. I'd rather increase operational cost in production than pay on SLA breaches that would cost more in damage."*

### Secret Weapon Phrases for Q4
- *"$20/month total budget — every choice is deliberate against that ceiling"*
- *"Multi-AZ doubles RDS cost — biggest single saver in my spec"*
- *"1-day backup isn't a cost saver — it's a destroy-friendly posture saver"*
- *"Customer-managed KMS for $1/month buys compliance narrative + key policy control"*
- *"Each lever has a specific upgrade signal — not arbitrary"*
- *"Cost decisions are stage-appropriate, not permanent"*
- *"I'd rather increase operational cost than pay on SLA breaches"*

### Likely Hostile Follow-ups for Q4

**Q4.F1: "What's the actual cost of an AZ outage with single-AZ? Walk me through what users see."**
> *"With single-AZ, if my AZ goes down, RDS becomes unreachable. AWS detects the failure and starts provisioning a replacement instance in the same AZ once it's healthy, or restores from snapshot in a different AZ if the AZ is extended-down. RTO is typically 10-20 minutes for instance replacement, longer if storage corruption requires snapshot restore. From the user side, Petclinic pods get JDBC connection failures, Spring Boot's HikariCP pool exhausts retries, requests start returning 500s. With multi-AZ, AWS would have failed over to the synchronous standby in ~60 seconds — most users would see a brief error spike, not a sustained outage. The cost of the outage: minutes of failed transactions per minute of downtime. For my portfolio with zero users, the cost is zero — that's why single-AZ is acceptable. Production with revenue-generating traffic, the math flips immediately."*

**Q4.F2: "You said 1-day backups are fine for portfolio. What if you needed to restore from yesterday morning at 9am — can you?"**
> *"Yes, within the 1-day retention window — RDS does continuous WAL backups, so I can point-in-time restore to any second within the retention period. If 'yesterday at 9am' is within 24 hours of now, I can restore. If it's more than 24 hours back, no — I'd be limited to the most recent automated snapshot, which is the previous day's nightly. For portfolio that's acceptable because there's no critical historical data. For production where someone might say 'we corrupted data 3 days ago and just noticed,' I'd want 7-30 day retention. The honest tradeoff is recovery window — my 1-day window assumes I notice problems same-day."*

**Q4.F3: "Customer-managed KMS at $1/month — defend why that's worth it when free AWS-managed would also encrypt the data."**
> *"Three reasons. One — key policy control. With customer-managed I write the key policy explicitly: which principals can encrypt, decrypt, or administer the key. With `aws/rds` AWS controls the policy and only the account root + RDS service can use it. Two — compliance frameworks. SOC2, HIPAA, PCI all require customer-managed keys for sensitive data — auditors flag AWS-managed as insufficient. Three — cross-account and cross-region scenarios. Customer-managed keys can be shared across accounts via key policy; AWS-managed keys cannot. For my portfolio, the practical value is the compliance signal in interview narrative — I'm showing I know the production posture. $1/month is rounding error against that signal."*

**Q4.F4: "How would you discover that t4g.micro has become undersized — what metrics?"**
> *"Four CloudWatch metrics tell the story. One — `CPUUtilization` sustained above 50%; t4g.micro uses CPU credits, so sustained high CPU exhausts credits and throttles to baseline. Two — `DatabaseConnections` approaching the connection limit (~80 for t4g.micro); HikariCP pool exhaustion in pods is a downstream symptom. Three — `FreeableMemory` dropping toward zero; with 1GB RAM and buffer pool needs, memory pressure causes swap and degrades query latency. Four — `ReadLatency` and `WriteLatency` climbing under load. I'd set CloudWatch alarms on each crossing thresholds, alerting via SNS. When two or more sustain over a week, that's the upgrade signal — bump to t4g.small or medium and re-baseline."*

**Q4.F5: "Your `skip_final_snapshot = true` is dangerous. Defend it."**
> *"Dangerous in production, deliberate for portfolio. `skip_final_snapshot = true` means `terraform destroy` deletes RDS without taking a final snapshot — so if I destroy and want the data back, I can't. For my portfolio that's the desired behavior because I run `infra-destroy.yaml` frequently to control costs overnight or between testing sessions, and a final snapshot adds 10+ minutes to destroy time plus storage cost. There's no precious data to protect. In production this flag would be `false` plus `deletion_protection = true`, requiring an explicit Terraform two-step to destroy: first remove the protection, then run destroy with a final snapshot. The portfolio's destroy-friendly posture wouldn't survive production review for 30 seconds — and it shouldn't. Different stage, different defaults."*

---

<a name="q5-rotation-behavior"></a>
## Q5: "You said the K8s Secret goes stale when AWS rotates the password. Walk me through EXACTLY what fails. Which pods break first, what's the error, when does the application notice, and how do you recover today without External Secrets Operator?"

**Round 1 — 2026-06-04 — Score: 5.5/10**
**Round 2 — 2026-06-05 — Score: 8.5/10** 🔒

### R2 Improvements Sai Applied
- ✅ **THE KILLER INSIGHT:** "Existing connections remain established — break only happens at pod restart" — captured the delayed-failure mechanism that defines this question
- ✅ Listed trigger events: OOM, image update, node eviction
- ✅ Exact error verbatim: `Access denied for user 'admin'@'...' (using password: YES)`
- ✅ Full health chain: HikariCP logs → /actuator/health DOWN → readiness probe fails → pod removed from endpoints → 503s
- ✅ 3-stage blast radius timeline clear (T=0, T+hours, T+days, T+7 days)
- ✅ 3-step manual recovery clear
- ✅ ESO closer with auto-sync framing

### Remaining Polish for 9+
- ⚠️ Said "kubectl argo rollout restart" — correct command for Deployments is `kubectl rollout restart deployment -n petclinic` (plain kubectl; argo rollouts plugin is for Rollout CRDs only)
- ⚠️ HikariCP framing slightly off — MySQL rejects new connections, HikariCP just relays the error
- ❌ Didn't mention ESO's deployment annotation hash trick (auto-triggers rolling restart)

### R2 Locked Ideal Answer (~120 seconds spoken)

> *"This is the killer scenario — and the failure mode is sneakier than people expect.*
>
> *When AWS rotates the master password, Secrets Manager updates the stored value immediately. RDS accepts the new password and rejects the old one for any new connection attempt. But existing established connections in the HikariCP pool are NOT re-validated — MySQL doesn't re-check the password mid-session. So pods with healthy connection pools KEEP WORKING after rotation.*
>
> *The K8s Secret in the petclinic namespace still holds the OLD password — my bootstrap fetched it once at startup. Pod env vars also still hold the OLD password — env vars are static for the pod's lifetime.*
>
> *So monitoring shows all green. Until a trigger event.*
>
> *Trigger events: any pod restart — OOM, node eviction, scale-up, image update, node replacement. Or HikariCP pool growth — new connections created under load. Or idle timeout — connections recycled.*
>
> *When the trigger happens, HikariCP tries to establish a new connection with the old password, MySQL returns `Access denied for user 'admin'@'...' (using password: YES)`, Spring Boot's `/actuator/health` returns DOWN, Kubernetes readiness probe fails, the pod is removed from Service endpoints, and user requests start returning 503.*
>
> *The blast radius progression: at T=0, invisible. T+hours, first eviction causes first pod failure. T+days, more pods cycle, more failures. By the next rotation 7 days later, the entire DB-dependent fleet — customers-service, visits-service, vets-service — has cycled and failed.*
>
> *Recovery today, without External Secrets Operator, is three steps. One — re-run the bootstrap workflow's secret-fetch step. It calls `aws secretsmanager get-secret-value` which always returns the CURRENT version, and re-creates the `mysql-credentials` K8s Secret with the new password using the idempotent `kubectl apply` pattern. Two — `kubectl rollout restart deployment -n petclinic` on all DB-dependent services to force pods to pick up the refreshed env vars. Three — verify recovery via `kubectl get pods -n petclinic` for Ready status and `kubectl logs` for successful DB connections.*
>
> *Total recovery time: 5-10 minutes manually. The production fix is External Secrets Operator — it watches Secrets Manager, re-syncs the K8s Secret on rotation, and triggers rolling restarts via a deployment annotation hash change. Fully automatic. I haven't wired ESO for portfolio scope, but the failure mode I just described is exactly why it's mandatory in production."*

### 🧠 Memory Tips for Q5

**The killer insight (THE concept that scores 8+):**
> *"Rotation breaks pods LATER, not immediately. Existing connections survive because MySQL doesn't re-validate mid-session. Break happens at the NEXT pod restart."*

**The 3-stage failure timeline (memorize):**
```
T=0 (rotation):    Secrets Manager updates. K8s Secret stale. Monitoring green.
T+hours:           First pod restart → HikariCP fails new connection → 503s start
T+days:            Cascading as more pods cycle (OOM, scale, eviction)
T+7 days:          Next rotation. Entire DB-dependent fleet likely broken.
```

**The trigger events (memorize the list):**
- Pod restart (OOM, eviction, scale-up, image update, node replacement)
- HikariCP pool growth (new connections under load)
- Idle timeout (connections recycled)

**The 3-step manual recovery (memorize):**
1. Re-run bootstrap secret-fetch (Secrets Manager always returns current)
2. `kubectl rollout restart deployment -n petclinic` for DB-dependent services
3. Verify via `kubectl get pods` + `kubectl logs`

**The exact error (memorize verbatim):**
> *"`Access denied for user 'admin'@'...' (using password: YES)` → HikariCP logs → /actuator/health DOWN → readiness probe fails → pod removed from endpoints → 503s"*

### Secret Weapon Phrases for Q5
- *"Existing connections survive rotation — MySQL doesn't re-validate mid-session"*
- *"The break is delayed and silent until a trigger event"*
- *"Trigger events: pod restart, pool growth, idle timeout"*
- *"By the next rotation, the entire DB-dependent fleet has cycled"*
- *"Recovery is mechanical — re-run bootstrap, rollout restart, verify"*
- *"ESO triggers rolling restart via deployment annotation hash — fully automatic"*

### Likely Hostile Follow-ups for Q5

**Q5.F1: "What if multiple pods restart simultaneously during rotation — what does the cluster look like?"**
> *"Worst case scenario. If something triggers fleet-wide restart — say a node drain, a deploy, or autoscaler event — all DB-dependent pods try to reconnect simultaneously, all fail with `Access denied`, all readiness probes go red, all are removed from Service endpoints. Petclinic effectively goes 100% down. Spring Cloud Gateway routes return 503 because no upstream is healthy. Argo Rollouts would block on the next deploy because health checks fail. Recovery is the same 3-step process, but the discovery is faster because the impact is immediate and total — paradoxically less dangerous than the slow cascading failure. The slow cascade is harder because it looks like 'random pod flakes' instead of 'rotation broke everything.'"*

**Q5.F2: "How would you DETECT that rotation just broke pods before users complain?"**
> *"Four signals. One — CloudWatch alarm on RDS `FailedSQLServerLogins` or equivalent metric spiking. Two — Prometheus alert on HikariCP `hikaricp_connections_acquire_seconds` failure rate; Spring Boot exposes this via Micrometer. Three — alert on Kubernetes pod readiness flapping in the petclinic namespace — sustained NotReady on DB-dependent deployments. Four — correlation alert: 'Secrets Manager secret version changed' EventBridge event from CloudTrail tied to a Kubernetes pod failure within 1 hour. For my portfolio I have CloudWatch metrics but not the correlation pipeline — that's the production gap. ESO would also expose its own metrics for sync success/failure, closing the loop."*

**Q5.F3: "Walk me through wiring External Secrets Operator end-to-end."**
> *"Four-step setup. One — install ESO via Helm: `helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace`. Two — create a `ClusterSecretStore` resource pointing at AWS Secrets Manager, authenticated via IRSA — ESO's ServiceAccount gets an IAM role with `secretsmanager:GetSecretValue` on the specific RDS secret ARN. Three — create an `ExternalSecret` resource in the petclinic namespace referencing the ClusterSecretStore and the RDS secret ARN; ESO reconciles every refreshInterval (default 1h) and writes/updates a K8s Secret called `mysql-credentials` with the latest values. Four — annotate the Petclinic deployments with `reloader.stakater.com/auto: 'true'` or use ESO's built-in `creationPolicy: Owner` plus a controller like Reloader that watches the Secret hash and triggers `kubectl rollout restart` automatically. Net result: rotation in Secrets Manager → 1-hour max delay → ESO syncs Secret → Reloader detects hash change → pods restart with new env vars. Zero manual ops."*

**Q5.F4: "Why doesn't HikariCP re-authenticate on each query?"**
> *"By design — connection pooling exists specifically to avoid the cost of repeated auth handshakes. MySQL authentication happens once per connection establishment. Once authenticated, the connection is a session — queries flow without re-auth. HikariCP holds the connection open as long as it's healthy (configurable max lifetime, default 30 min). This is great for performance — sub-millisecond query latency vs ~10ms for connect+auth+query. The downside is exactly what we're discussing: stale credentials don't get caught until the connection is recycled. Could you build a periodic auth re-check? Yes — but the standard pattern is 'rotate credentials, recycle pool' which is what ESO + Reloader does. Don't fight the connection pooling model; work with it."*

**Q5.F5: "What if your bootstrap workflow itself can't run because the runner is down?"**
> *"Self-hosted runner on EC2 is a single point of failure for recovery. Three mitigations. One — make bootstrap runnable on GitHub-hosted runners as a fallback: requires public EKS endpoint OR a VPC tunnel like Tailscale, both add cost/complexity. Two — pre-stage the recovery as a documented runbook with raw `aws` and `kubectl` commands that I can run from any machine with AWS creds and kubeconfig — emergency recovery doesn't require the workflow. Three — for production, use ESO so the recovery doesn't depend on workflow runs at all — the cluster heals itself. Portfolio reality: if my runner is down, I `terraform apply` to recreate it (~3 min) and then re-run bootstrap. Adds ~5 min to total recovery time. Acceptable for portfolio; production needs a runnerless recovery path."*

---

## Phase 6 — Trajectory ✅ COMPLETE

| Question | R1 | R2 |
|---|---|---|
| Q1 — Credential lifecycle | 5.5/10 | **8.5/10** 🔒 |
| Q2 — RDS vs in-cluster MySQL | **7.0/10** 🔒 | — |
| Q3 — Network isolation | **8.0/10** 🔒 | — |
| Q4 — Cost defense | 6.5/10 | **8.0/10** 🔒 |
| Q5 — Rotation behavior | 5.5/10 | **8.5/10** 🔒 |

### **Phase 6 Final Average: 8.0/10** — highest after Phase 4 (8.5). Interview-locked.
