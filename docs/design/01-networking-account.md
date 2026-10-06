# LLD 1 — Networking Account: VPC Design for EKS

**Purpose:** Low-level network design for an EKS cluster hosting a public front-end service and a private back-end service.
**Owner:** Networking account (AWS Organizations landing zone).
**Consumers:** Shared Services account (EKS) via AWS RAM subnet sharing.

---

## 1. Context & Assumptions

- The organisation follows the AWS landing-zone pattern: a dedicated **Networking account** owns all VPCs, subnets, gateways and route tables. Workload accounts never create their own networks.
- Subnets are **shared to the Shared Services account via AWS Resource Access Manager (RAM)**. The consuming account can launch ENIs/nodes into shared subnets and create Security Groups, but cannot create, modify or tag subnets or route tables.
- Region: `us-east-1`, three Availability Zones.
- Two exposure tiers are required:
  - **Public front-end** — reachable from the internet over HTTPS.
  - **Private back-end** — reachable only from the front-end, never from the internet.
- A relational database sits behind the back-end.

> **Implementation note:** My working build collapses Networking and Shared Services into one AWS account. The VPC/subnet/route-table/SG constructs are identical; only the ownership boundary and the RAM share differ.

## 2. Requirements

| # | Requirement | Type |
|---|---|---|
| R1 | Front-end reachable from the internet on 443 only | Functional |
| R2 | Back-end not reachable from the internet; reachable only from front-end | Functional |
| R3 | Database reachable only from the application tier | Functional |
| R4 | Nodes can pull images / call AWS APIs without being internet-reachable | Functional |
| R5 | Loss of one AZ does not take the service down | Availability |
| R6 | Address space sized for pod-per-IP networking (EKS VPC CNI) with room to grow | Scalability |
| R7 | CIDR must not overlap with any current or future peered/on-prem network | Interoperability |
| R8 | Cost proportional to environment (non-prod may trade HA for cost) | Cost |

## 3. Design

### 3.1 VPC

| Item | Decision | Rationale | Rejected |
|---|---|---|---|
| CIDR | `10.0.0.0/16` (65,536 IPs) | RFC 1918 `10/8` is the largest private block, giving the org room to allocate one `/16` per environment/VPC. Avoids `172.17.0.0/16` (Docker default bridge) and `192.168.0.0/16` (home/VPN collisions). | `/20` — too small once every pod consumes a VPC IP. `172.16/12` — Docker collision risk. |
| Allocation | Registered in **AWS VPC IPAM** (org-level pool) | Guarantees non-overlap across accounts, enabling future peering / Transit Gateway / VPN. | Spreadsheet — drifts. |
| DNS | `enableDnsSupport` + `enableDnsHostnames` = true | Required by EKS and by interface VPC endpoints (private DNS). | — |
| Tenancy | default | Dedicated tenancy is a cost multiplier with no benefit here. | — |

### 3.2 Subnets — 3 tiers × 3 AZs = 9 subnets

Sizing is **asymmetric on purpose**: each tier is sized for what actually lives in it.

| Tier | AZ-a | AZ-b | AZ-c | Usable/subnet | Hosts |
|---|---|---|---|---|---|
| **Public** | `10.0.0.0/24` | `10.0.1.0/24` | `10.0.2.0/24` | 251 | ALB nodes, NAT Gateways only |
| **Private-app** | `10.0.16.0/20` | `10.0.32.0/20` | `10.0.48.0/20` | 4,091 | EKS worker nodes + **pod ENIs** |
| **Private-data** | `10.0.64.0/24` | `10.0.65.0/24` | `10.0.66.0/24` | 251 | RDS, ElastiCache |
| *Reserved* | `10.0.80.0/20` → `10.0.255.0/24` | | | | Future tiers (Fargate, TGW attachment, second cluster) |

**Why the app tier is a `/20`:** The AWS VPC CNI assigns **every pod a routable VPC IP** from the subnet (no overlay). It also pre-allocates a warm pool of IPs per node. So subnet capacity ≈ pod capacity, not node capacity. A `/24` (251 IPs) supports roughly 20 small nodes before exhaustion; a `/20` supports ~350+ nodes at typical pod densities.

**Why public is only a `/24`:** ALBs consume ~8 IPs per subnet at scale; NAT Gateways consume 1. Nothing else belongs there.

**Why a separate data tier:** the data subnets have **no default route at all** — no IGW, no NAT. Even a misconfigured Security Group cannot expose the database to the internet, because there is no path.

**EKS subnet tags (applied by the Networking account, since the consumer cannot tag shared subnets):**

| Subnet tier | Tag | Purpose |
|---|---|---|
| Public | `kubernetes.io/role/elb = 1` | AWS Load Balancer Controller places **internet-facing** ALBs here |
| Private-app | `kubernetes.io/role/internal-elb = 1` | Controller places **internal** ALBs/NLBs here |
| All | `kubernetes.io/cluster/<name> = shared` | Cluster discovery (legacy, still harmless) |

`map_public_ip_on_launch = false` on **all** subnets, including public — nothing should get a public IP implicitly; ALB and NAT get theirs explicitly.

### 3.3 Internet Gateway

| Item | Decision |
|---|---|
| Count | 1 per VPC (AWS limit is 1) |
| Referenced by | Public route table only |
| Function | Stateless 1:1 NAT between public IPs (EIPs / ALB) and private VPC IPs. Horizontally scaled and HA by AWS — no design work needed. |

### 3.4 NAT Gateway

| Option | Cost (us-east-1, approx.) | Availability | Data transfer |
|---|---|---|---|
| **1 NAT in AZ-a** | ~$32/mo + $0.045/GB | AZ-a failure = **all** private egress fails | AZ-b/c nodes pay cross-AZ transfer to reach it |
| **1 NAT per AZ (3)** | ~$97/mo + $0.045/GB | AZ-isolated; loss of one AZ affects only that AZ | Each AZ egresses locally — no cross-AZ charge |

**Decision:** **1 NAT per AZ for production; 1 NAT total for non-prod** (controlled by a Terraform variable). Production must satisfy R5; non-prod optimises for R8.

**Reduce NAT dependency regardless** with VPC Endpoints (§3.7) — image pulls and AWS API calls never touch the NAT, which cuts both cost and blast radius.

### 3.5 Route tables

| Route table | Associated subnets | Destination | Target |
|---|---|---|---|
| `rt-public` | 3 public | `10.0.0.0/16` | local |
| | | `0.0.0.0/0` | **igw** |
| `rt-private-a` | private-app-a | `10.0.0.0/16` | local |
| | | `0.0.0.0/0` | **nat-a** |
| | | S3 / DynamoDB prefix lists | vpce-gateway |
| `rt-private-b` | private-app-b | same, `0.0.0.0/0` → **nat-b** | |
| `rt-private-c` | private-app-c | same, `0.0.0.0/0` → **nat-c** | |
| `rt-data` | 3 data | `10.0.0.0/16` | local |
| | | *(no default route)* | — |

Key rule: **one private route table per AZ**, so each AZ's default route points at the NAT in the *same* AZ. A single shared private route table would silently re-introduce the single-NAT failure mode.

A subnet is "public" *only because* its route table has `0.0.0.0/0 → igw`. Nothing else makes it public.

### 3.6 Security — Security Groups and NACLs

AWS has no "NSG" object; the equivalent is **Security Groups** (stateful, ENI-level, allow-only) backed by **Network ACLs** (stateless, subnet-level, allow+deny).

**Security Group chain — reference by SG ID, never by CIDR:**

| SG | Attached to | Inbound | Outbound |
|---|---|---|---|
| `sg-alb` | Internet-facing ALB | `443` from `0.0.0.0/0` (and `80` → redirect to 443) | to `sg-node` on pod port range |
| `sg-node` | EKS worker nodes | from `sg-alb` on pod ports; **all** from `sg-node` (pod-to-pod, kubelet); `443` from `sg-cluster` | `0.0.0.0/0` (via NAT / endpoints) |
| `sg-cluster` | EKS control-plane ENIs | `443` from `sg-node` | to `sg-node` `1025-65535` |
| `sg-rds` | RDS | `3306` from `sg-node` **only** | none |
| `sg-vpce` | Interface endpoints | `443` from `sg-node` | none |

Why SG-by-ID: if the ALB or nodes scale to new IPs, the rule still holds. CIDR rules rot.

**NACLs — coarse backstop, not the primary control:**

| NACL | Inbound allow | Inbound deny | Outbound |
|---|---|---|---|
| `nacl-public` | 80, 443 from `0.0.0.0/0`; ephemeral `1024-65535` | everything else | all |
| `nacl-private` | all from `10.0.0.0/16`; ephemeral `1024-65535` from `0.0.0.0/0` (return traffic) | `0.0.0.0/0` on 22, 3389 | all |
| `nacl-data` | `3306` from `10.0.16.0/20`, `10.0.32.0/20`, `10.0.48.0/20` | all else | ephemeral to app subnets |

NACLs are stateless — the ephemeral-port return rule is mandatory or nothing works. They exist to block obvious mistakes (e.g. someone opening SSH on a node SG) at the subnet boundary.

**Inside the cluster:** pod-to-pod isolation between front-end and back-end is enforced by Kubernetes **NetworkPolicy** (see LLD 2), since SGs operate at the node level and both tiers share nodes.

### 3.7 VPC Endpoints (PrivateLink)

| Endpoint | Type | Cost | Why |
|---|---|---|---|
| `com.amazonaws.us-east-1.s3` | Gateway | free | ECR image layers are stored in S3 |
| `com.amazonaws.us-east-1.dynamodb` | Gateway | free | Terraform state locking, app use |
| `ecr.api`, `ecr.dkr` | Interface | ~$7/mo each + $0.01/GB | Image pulls without NAT |
| `sts` | Interface | ~$7/mo | IRSA token exchange |
| `logs`, `monitoring` | Interface | ~$7/mo each | CloudWatch without NAT |
| `eks` | Interface | ~$7/mo | kubectl / node bootstrap to private API |

Interface endpoints deploy one ENI per AZ in the private-app subnets, attached to `sg-vpce`. With these in place, a NAT outage degrades only *external* egress (e.g. third-party APIs), not cluster operation.

### 3.8 Observability & hygiene

- **VPC Flow Logs** → S3 (Parquet, 90-day lifecycle) for forensics; **REJECT**-only stream → CloudWatch for alerting.
- **Route 53 Private Hosted Zone** for internal service names.
- **Default SG**: all rules removed. **Default NACL**: unused.
- Tagging: `Environment`, `Owner`, `CostCenter`, `SharedWith` on every resource.

## 4. Diagram

```
                                   INTERNET
                                       │
                               ┌───────▼────────┐
                               │ Internet GW    │
                               └───────┬────────┘
 ┌──────────────────────── VPC 10.0.0.0/16 ─────────────────────────────────┐
 │           AZ-a                    AZ-b                    AZ-c           │
 │  ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────┐      │
 │  │ PUBLIC 10.0.0/24 │   │ PUBLIC 10.0.1/24 │   │ PUBLIC 10.0.2/24 │      │
 │  │  ALB-ENI  NAT-a  │   │  ALB-ENI  NAT-b  │   │  ALB-ENI  NAT-c  │      │
 │  └───┬─────────▲────┘   └───┬─────────▲────┘   └───┬─────────▲────┘      │
 │  rt-public: 0/0→igw   (shared by all three)                              │
 │      │:443 sg-alb→sg-node │             │             │             │      │
 │  ┌───▼─────────┴────┐   ┌───▼─────────┴────┐   ┌───▼─────────┴────┐      │
 │  │ PRIV-APP         │   │ PRIV-APP         │   │ PRIV-APP         │      │
 │  │ 10.0.16/20       │   │ 10.0.32/20       │   │ 10.0.48/20       │      │
 │  │ EKS nodes + pods │   │ EKS nodes + pods │   │ EKS nodes + pods │      │
 │  │ VPCE ENIs        │   │ VPCE ENIs        │   │ VPCE ENIs        │      │
 │  └───┬──────────────┘   └───┬──────────────┘   └───┬──────────────┘      │
 │  rt-private-a: 0/0→nat-a  rt-private-b: 0/0→nat-b  rt-private-c: 0/0→nat-c│
 │      │:3306 sg-node→sg-rds │                       │                     │
 │  ┌───▼──────────────┐   ┌───▼──────────────┐   ┌───▼──────────────┐      │
 │  │ PRIV-DATA        │   │ PRIV-DATA        │   │ PRIV-DATA        │      │
 │  │ 10.0.64/24  RDS  │   │ 10.0.65/24 RDS-s │   │ 10.0.66/24       │      │
 │  └──────────────────┘   └──────────────────┘   └──────────────────┘      │
 │  rt-data: local only — NO default route                                   │
 └───────────────────────────────────────────────────────────────────────────┘
        │ RAM share: 9 subnets → Shared Services account
```

## 5. Traffic flows

| # | Flow | Path | Controls |
|---|---|---|---|
| F1 | User → front-end | Internet → IGW → ALB (public) → pod IP (private-app) | `sg-alb` 443; `sg-node` from `sg-alb`; ALB target-type `ip` |
| F2 | Front-end → back-end | pod → pod (same VPC, may cross AZ) | `sg-node` self-reference; K8s NetworkPolicy |
| F3 | Back-end → DB | pod → RDS ENI (private-data) | `sg-rds` 3306 from `sg-node`; `nacl-data` |
| F4 | Node → ECR / STS / CloudWatch | pod → interface endpoint ENI | `sg-vpce` 443; never leaves VPC |
| F5 | Node → external internet | pod → rt-private-x → NAT-x → IGW | NAT is one-way; no inbound possible |
| F6 | kubectl → API server | VPN/bastion → `eks` endpoint or private ENI | `sg-cluster` 443 |

## 6. HA & cost summary

| Choice | Prod | Non-prod | Monthly delta |
|---|---|---|---|
| NAT Gateways | 3 | 1 | ~$65 |
| Interface endpoints | 6 | 2 (ecr.api, ecr.dkr) | ~$28 |
| Flow logs | S3 + CW reject | S3 only | ~$5 |

## 7. Future extensions

- **Transit Gateway** attachment (from the reserved block) for multi-VPC and on-prem.
- **Centralised egress VPC** with AWS Network Firewall for outbound inspection.
- **Secondary CIDR (`100.64.0.0/16`, CG-NAT range)** dedicated to pod IPs via VPC CNI custom networking, if the primary range is ever exhausted.
- IPv6 dual-stack for future pod addressing.
