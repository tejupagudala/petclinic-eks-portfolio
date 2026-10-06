# LLD 2 — Shared Services Account: EKS Design

**Purpose:** Low-level EKS design hosting a public front-end service and a private back-end service on subnets shared from the Networking account (see LLD 1).
**Owner:** Shared Services account.

---

## 1. Context & Assumptions

- The Shared Services account hosts platform capabilities consumed by multiple teams: this EKS cluster, ECR, CI runners, observability.
- **It does not own the network.** The 9 subnets from LLD 1 arrive via RAM. This account can place ENIs/nodes in them and create Security Groups; it cannot create or tag subnets. EKS load-balancer discovery tags are therefore a Networking-account responsibility.
- Workloads: a **front-end** (API gateway / web tier) that must be internet-reachable, and **back-end** services (business logic + DB access) that must not be.
- Region `us-east-1`, 3 AZs.

## 2. Design principles

1. **No worker node is ever in a public subnet.** "Public front-end" is delivered by an internet-facing ALB in the public subnets forwarding to pods in private subnets. Nodes never hold public IPs.
2. **Front-end and back-end differ by exposure, not by subnet.** Both run in private-app subnets. The difference is: front-end has an Ingress; back-end has only a ClusterIP Service and a NetworkPolicy.
3. **Separate nodegroups by failure domain, not by tier for its own sake.** System add-ons must not die when spot capacity is reclaimed.
4. **Every AZ, every tier.** All nodegroups span the three private-app subnets.

## 3. Cluster

| Item | Decision | Rationale |
|---|---|---|
| Kubernetes version | 1.34 | Latest with extended support runway; avoid paying extended-support fees. |
| Control-plane ENIs | Private-app subnets (all 3 AZs) | EKS requires ≥2 AZs; control plane is managed and multi-AZ by AWS. |
| API endpoint | **Private** enabled; **public** disabled in prod (enabled with CIDR allowlist in non-prod for developer convenience) | Removes the API server from the internet. Access via VPN / bastion / `eks` interface endpoint. |
| Auth | IAM → **EKS Access Entries** (not aws-auth ConfigMap); RBAC via ClusterRoles | Access entries are declarative and auditable. |
| Pod IAM | **EKS Pod Identity** (or IRSA where a chart lacks Pod Identity support) | Pods get scoped IAM roles; node role has no application permissions. |
| Cluster SG | `sg-cluster` from LLD 1 | 443 from nodes only. |
| Logging | API, audit, authenticator → CloudWatch | Audit trail. |
| Secrets | KMS envelope encryption of etcd secrets | Baseline. |
| Add-ons (managed) | `vpc-cni`, `coredns`, `kube-proxy`, `aws-ebs-csi-driver`, `eks-pod-identity-agent` | Managed lifecycle. |
| Add-ons (Helm) | AWS Load Balancer Controller, Metrics Server, Cluster Autoscaler *or* Karpenter, kube-prometheus-stack, External Secrets Operator, Argo Rollouts | Platform layer. |

### Tenancy

**One cluster, namespace-per-tier**, not cluster-per-service.

| Namespace | Holds | Node placement |
|---|---|---|
| `kube-system` / `platform` | add-ons, controllers, monitoring | `ng-system` |
| `frontend` | API gateway / web | `ng-frontend` |
| `backend` | business services | `ng-backend` |

Rationale: a single cluster halves fixed cost ($73/mo control plane each) and simplifies operations; namespaces + NetworkPolicy + RBAC + resource quotas give sufficient isolation for two tiers of one application. Cluster-per-environment (prod / non-prod) is still recommended; cluster-per-tier is not.

## 4. Nodegroups — the core of the design

### 4.1 Nodegroup table

| Nodegroup | Subnets | Instance types | Capacity | Min / Desired / Max | Taint | Label | Runs |
|---|---|---|---|---|---|---|---|
| `ng-system` | private-app a, b, c | `m6i.large` (`t3.medium` non-prod) | **ON_DEMAND** | 2 / 3 / 4 | `CriticalAddonsOnly=true:NoSchedule` | `role=system` | CoreDNS, ALB controller, Autoscaler/Karpenter, Prometheus, ESO, Argo |
| `ng-frontend` | private-app a, b, c | `m6i.large`, `m5.large`, `m6a.large` | ON_DEMAND baseline + SPOT burst (or 100% on-demand in prod) | 3 / 3 / 9 | none | `role=frontend` | API gateway / web pods |
| `ng-backend` | private-app a, b, c | `m6i.xlarge`, `m5.xlarge`, `m6a.xlarge` | **SPOT** (diversified) | 3 / 3 / 12 | `workload=backend:NoSchedule` | `role=backend` | Business services |

**Why every nodegroup lists all three subnets:** the ASG behind a managed nodegroup balances instances across the listed subnets/AZs, so each tier survives an AZ loss (R5). One nodegroup per tier spanning 3 AZs, *not* one nodegroup per AZ — the autoscaler then handles AZ balance via `topologySpreadConstraints`.

**Why `ng-system` is on-demand and tainted:** if CoreDNS or the ALB controller is evicted by a spot reclaim, *every* tier degrades. Taint keeps application pods off these nodes so they stay predictable.

**Why `ng-backend` can be spot:** back-end pods are stateless, replicated ≥3, and fronted by ClusterIP services. With a PodDisruptionBudget and 3+ instance types across 3 AZs, a spot reclaim is a rolling event, not an outage. Savings ~60–70%.

**Why `ng-frontend` keeps an on-demand baseline:** it is the user-facing tier and ALB health checks are the first thing customers notice. Baseline on-demand guarantees minimum capacity; spot handles burst.

**Why no nodes in public subnets (repeated because it's the most common mistake):** nodes in a public subnet would need public IPs or would sit behind an IGW route with no benefit — the ALB already provides ingress. It only expands the attack surface.

### 4.2 Nodegroup ↔ subnet allocation

```
                Subnet         AZ-a               AZ-b               AZ-c
                ──────────     ────────────────   ────────────────   ────────────────
  PUBLIC         (no nodes)     ALB-ENI, NAT-a     ALB-ENI, NAT-b     ALB-ENI, NAT-c
  PRIVATE-APP    ng-system      ● on-demand        ● on-demand        ● on-demand
                 ng-frontend    ● od + ○ spot      ● od + ○ spot      ● od + ○ spot
                 ng-backend     ○ spot ○ spot      ○ spot ○ spot      ○ spot ○ spot
  PRIVATE-DATA   (no nodes)     RDS primary        RDS standby        —
```

### 4.3 Terraform shape (managed nodegroups)

```hcl
node_groups = {
  system = {
    subnet_ids     = local.private_app_subnet_ids            # all 3 AZs
    instance_types = ["m6i.large"]
    capacity_type  = "ON_DEMAND"
    scaling_config = { min_size = 2, desired_size = 3, max_size = 4 }
    labels         = { role = "system" }
    taints         = [{ key = "CriticalAddonsOnly", value = "true", effect = "NO_SCHEDULE" }]
  }
  frontend = {
    subnet_ids     = local.private_app_subnet_ids
    instance_types = ["m6i.large", "m5.large", "m6a.large"]
    capacity_type  = "ON_DEMAND"
    scaling_config = { min_size = 3, desired_size = 3, max_size = 9 }
    labels         = { role = "frontend" }
    taints         = []
  }
  backend = {
    subnet_ids     = local.private_app_subnet_ids
    instance_types = ["m6i.xlarge", "m5.xlarge", "m6a.xlarge"]
    capacity_type  = "SPOT"
    scaling_config = { min_size = 3, desired_size = 3, max_size = 12 }
    labels         = { role = "backend" }
    taints         = [{ key = "workload", value = "backend", effect = "NO_SCHEDULE" }]
  }
}
```

### 4.4 Alternative: Karpenter NodePools

For production at scale, replace `ng-frontend` / `ng-backend` with **Karpenter** `NodePool` objects (keep `ng-system` as a managed nodegroup to run Karpenter itself). Karpenter picks instance type per pending pod, consolidates under-used nodes, and handles spot interruption natively — better bin-packing than ASG-based autoscaling. Same subnet selection via `subnetSelectorTerms` on the `kubernetes.io/role/internal-elb` tag.

## 5. Front-end vs back-end — how they differ

| Aspect | Front-end | Back-end |
|---|---|---|
| Kubernetes objects | `Deployment` (or Argo `Rollout` for canary) + `Service` + **`Ingress`** | `Deployment` + **`ClusterIP` Service** only |
| Load balancer | **Internet-facing ALB** (`alb.ingress.kubernetes.io/scheme: internet-facing`), placed in `kubernetes.io/role/elb` subnets by the ALB controller | **None.** If ever needed: internal ALB/NLB (`scheme: internal`) in `internal-elb` subnets |
| ALB target type | `ip` — ALB forwards straight to pod IPs in private-app subnets (no NodePort hop) | n/a |
| TLS | ACM certificate on the ALB; HTTP→HTTPS redirect | mTLS via mesh (optional, future) |
| Pod subnet | private-app | private-app |
| Nodegroup | `ng-frontend` via `nodeSelector: role=frontend` | `ng-backend` via `nodeSelector` + toleration `workload=backend` |
| Reachable from | Internet → ALB → pod | `frontend` namespace only |
| Security Group path | `sg-alb` → `sg-node` | `sg-node` → `sg-node`, then `sg-node` → `sg-rds` |
| NetworkPolicy | ingress: from ALB (via node CIDR) ; egress: to `backend` namespace + DNS | ingress: **only** from `namespace=frontend`; egress: DB `3306` + DNS |
| Service discovery | Kubernetes DNS (`svc.backend.svc.cluster.local`) | same |
| Scaling | HPA on request rate / CPU | HPA on CPU / queue depth |

### Request path

```
User ──443──▶ ALB (public subnet, sg-alb)
             ──pod port──▶ frontend pod (private-app, sg-node, ng-frontend)
                          ──ClusterIP──▶ backend pod (private-app, sg-node, ng-backend)
                                        ──3306──▶ RDS (private-data, sg-rds)
```

Every hop has a Security Group *and* a NetworkPolicy; the NetworkPolicy is what separates the tiers since both share `sg-node`.

### NetworkPolicy — back-end (the policy that makes it "private")

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: backend-ingress, namespace: backend }
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
        - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: frontend } }
        - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: monitoring } }
  egress:
    - to: [{ ipBlock: { cidr: 10.0.64.0/22 } }]         # private-data subnets
      ports: [{ port: 3306, protocol: TCP }]
    - to: [{ namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: kube-system } } }]
      ports: [{ port: 53, protocol: UDP }, { port: 53, protocol: TCP }]
```

Enforced by **VPC CNI network-policy mode** (`enableNetworkPolicy: true`) — no extra CNI needed.

## 6. Scheduling controls that make the allocation real

Nodegroups only create capacity; these place pods on it.

| Control | Applied to | Effect |
|---|---|---|
| `nodeSelector` / `nodeAffinity` on `role` label | every workload | Pins pods to the intended nodegroup |
| Taints + tolerations | `ng-system`, `ng-backend` | Keeps the *wrong* pods off — selectors alone don't |
| `topologySpreadConstraints` on `topology.kubernetes.io/zone` (`maxSkew: 1`) | every workload | Even AZ distribution; survives AZ loss |
| `podAntiAffinity` (preferred, per hostname) | front-end, back-end | No two replicas on one node |
| `PodDisruptionBudget` (`minAvailable: 2`) | every workload | Spot reclaim / upgrades can't drain below quorum |
| Requests & limits + `ResourceQuota` per namespace | every namespace | One tier can't starve another |
| `PriorityClass` (`system-cluster-critical` for add-ons) | `platform` | Add-ons pre-empt app pods under pressure |
| HPA + Cluster Autoscaler / Karpenter | app tiers | Pods scale → nodes scale |

## 7. Networking details inside the cluster

- **VPC CNI = one VPC IP per pod.** Subnet size is pod budget. `m6i.large` supports 29 pods (3 ENI × 10 IP − 1); with **prefix delegation** enabled (`ENABLE_PREFIX_DELEGATION=true`) it supports 110, and IP consumption becomes /28 blocks per node — plan subnets for that.
- **Warm pool**: CNI keeps `WARM_ENI_TARGET=1` worth of IPs pre-attached per node; tune `WARM_IP_TARGET` on small subnets.
- **Image pulls** go through ECR/S3 endpoints (LLD 1 §3.7), so a NAT outage does not block scaling.
- **CoreDNS**: 2+ replicas on `ng-system`, `podAntiAffinity`, plus **NodeLocal DNSCache** at scale.
- **ALB target type `ip`** means the ALB registers pod IPs directly — this is why pods must be in VPC-routable subnets and why `sg-node` must allow `sg-alb`.
- **kube-proxy** in IPVS mode for large service counts.

## 8. Security

| Layer | Control |
|---|---|
| Cluster | Private API endpoint; access entries; audit logs |
| Node | Bottlerocket or AL2023 AMI; IMDSv2 required (`http_tokens = required`, hop limit 1) so pods can't steal the node role; SSM instead of SSH; no public IPs |
| Pod | Pod Security Standards `restricted` on app namespaces: non-root, read-only rootfs, drop all caps, seccomp `RuntimeDefault` |
| Identity | Pod Identity / IRSA per service; node role = ECR pull + CNI + SSM only |
| Secrets | External Secrets Operator → Secrets Manager; no secrets in Git |
| Network | Security Groups (node boundary) + NetworkPolicy (pod boundary) — defence in depth |
| Supply chain | Image scanning in ECR; admission policy (Kyverno) blocks `:latest` and unsigned images |

## 9. Cost & HA trade-offs

| Decision | Prod | Non-prod |
|---|---|---|
| `ng-system` | 3 × on-demand | 2 × on-demand `t3.medium` |
| `ng-frontend` | 3 on-demand baseline, spot burst | 2 spot |
| `ng-backend` | spot, 3 types, 3 AZs | spot, min 1 |
| Scale-to-zero | never | nightly (cron) |
| Control plane | $73/mo fixed | same |

## 10. Diagram

```
 ┌────────────── Shared Services account ───────────────────────────────────────────┐
 │  EKS control plane (managed, multi-AZ, private endpoint) ─── sg-cluster          │
 │                                                                                  │
 │  ┌─ RAM-shared subnets from Networking account ──────────────────────────────┐   │
 │  │  PUBLIC a/b/c        ┌─────────────────────────┐                          │   │
 │  │                      │ internet-facing ALB     │◀── 443 ── Internet       │   │
 │  │                      │ (kubernetes.io/role/elb)│                          │   │
 │  │                      └───────────┬─────────────┘                          │   │
 │  │  PRIVATE-APP a/b/c               │ target-type: ip                        │   │
 │  │   ┌──────────────┐   ┌───────────▼─────────────┐   ┌────────────────────┐ │   │
 │  │   │ ng-system    │   │ ng-frontend             │   │ ng-backend         │ │   │
 │  │   │ on-demand    │   │ od + spot               │   │ spot               │ │   │
 │  │   │ taint: crit  │   │ ns: frontend            │──▶│ ns: backend        │ │   │
 │  │   │ coredns, alb │   │ Ingress + Rollout       │CIP│ ClusterIP only     │ │   │
 │  │   │ ctrl, prom   │   │                         │   │ NetworkPolicy      │ │   │
 │  │   └──────────────┘   └─────────────────────────┘   └─────────┬──────────┘ │   │
 │  │                                                              │ 3306        │   │
 │  │  PRIVATE-DATA a/b/c                                 ┌────────▼──────────┐ │   │
 │  │                                                     │ RDS (sg-rds)      │ │   │
 │  │                                                     └───────────────────┘ │   │
 │  └────────────────────────────────────────────────────────────────────────────┘   │
 └──────────────────────────────────────────────────────────────────────────────────┘
```
