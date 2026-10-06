# Terraform Modules — study notes

## What the mentor asked for

> "Terraform modules for `eks-network` and `eks`, to accommodate your design. Should be as minimal code as possible."

In plain words: you drew a design. Now write it as Terraform, in two modules, using as few lines as it honestly takes.

The two modules are the two tabs of the diagram (`docs/architecture/eks-landing-zone-lld.drawio`):

- Tab 1, the Networking account → module `eks-network`
- Tab 2, the Shared Services account → module `eks`

We have one AWS account, so both modules live in the same place. In a real landing zone, the boundary between them is where the network team would share subnets to the platform team using AWS RAM.

## What a module is, in one paragraph

A module is a folder of Terraform files that describes a group of resources and takes inputs. Think of it as a recipe that asks for ingredients. `variables.tf` lists the ingredients it needs. `main.tf` is the recipe. `outputs.tf` is what it hands back when done. The actual ingredient values — `10.0.0.0/16`, the AZ names — come from whoever *calls* the module (our root `terraform/main.tf`). Same recipe, different ingredients, different environment. That's why prod and dev don't need separate code.

## Module 1 — `eks-network` (done)

Three files, about 235 lines, 14 resources. Validates clean. tflint clean.

### The inputs (`variables.tf`)

Nine variables. Each one is a row in the design table:

- `name`, `cluster_name` — naming and the tags EKS reads
- `vpc_cidr` — the big box, `10.0.0.0/16`
- `availability_zones` — the three columns
- `public_subnet_cidrs`, `app_subnet_cidrs`, `data_subnet_cidrs` — the three rows, one CIDR per AZ
- `nat_per_az` — the one real decision (below)
- `tags` — housekeeping

Seven of these are required. Two have defaults (`nat_per_az = false`, `tags = {}`).

### The one decision: `nat_per_az`

A NAT gateway lives in one AZ. If that AZ dies, that NAT dies.

- `nat_per_az = true` → three NATs, one per AZ. Each AZ's private subnet routes through its own NAT. If AZ a fails, AZ b and c keep working. This is prod. About $97/month.
- `nat_per_az = false` → one NAT in AZ a. All three private subnets route through it. If AZ a fails, everyone loses internet access. This is non-prod, and it's what we run. About $32/month.

The whole switch is one line of code:
```
count = var.nat_per_az ? length(var.availability_zones) : 1
```
"If NAT per AZ, make three. Otherwise make one."

### What it builds (`main.tf`), top to bottom

**The VPC.** The dashed box. One resource. DNS turned on because EKS needs it.

**The internet gateway.** The door at the top. One per VPC. It does nothing on its own — it only carries traffic once a route table points at it.

**Nine subnets — three tiers × three AZs.** Three resources, each with `count = 3`. The AZ and the CIDR are read from the same position in their lists, so subnet number 1 is always AZ b with the second CIDR.

- Public: `/24` each. Only the ALB and NAT go here. `map_public_ip_on_launch = false` so nothing gets a public IP by accident. Tagged `kubernetes.io/role/elb` — that's how the load balancer controller knows "internet-facing ALBs go here."
- App: `/20` each — much bigger, because the VPC CNI gives every pod its own VPC IP, so this subnet is really a pod budget. Tagged `kubernetes.io/role/internal-elb`.
- Data: `/24` each. Only RDS. No Kubernetes tags at all, so nothing in the cluster is ever placed here.

**NAT gateways, one or three.** Each needs an Elastic IP (a fixed public address) and sits in the public subnet of its AZ.

**Three route tables — this is the heart of the design.**

- `rt-public` — one table, one route: `0.0.0.0/0 → internet gateway`. Attached to all three public subnets. This route is the *only* thing that makes a subnet public.
- `rt-app` — three tables, one per AZ, each with `0.0.0.0/0 → NAT`. Which NAT? "My own AZ's if there is one, otherwise the single one." Why three tables and not one: a table can only hold one default route, so AZ b can only point at NAT b if it has its own table.
- `rt-data` — one table with **no routes written at all**. AWS adds the "inside the VPC" route automatically. Nothing else exists. So there is no path to the internet in either direction. That's the guarantee: even if someone breaks the database's security group, packets have nowhere to go. The absence is the feature.

**An S3 gateway endpoint.** A free route that says "traffic to S3 doesn't go through the NAT — go straight there on AWS's private network." Attached to the three app route tables.

### What it hands back (`outputs.tf`)

The VPC ID and the three subnet lists. The EKS module takes the app subnets. The RDS subnet group takes the data subnets. The load balancer controller finds the public subnets by tag. The network never needs to know about EKS or RDS — they depend on it, not the other way round.

### Why `count` and not `for_each`

Two ways to make three of something. `count` numbers them 0, 1, 2. `for_each` names them by AZ. `for_each` is safer if you ever remove the *middle* AZ (with `count`, the third one gets renumbered and recreated). We picked `count` because it's simpler, it matches the existing code in the repo, and we're not going to remove AZs. If asked: "AZs are stable and positional here; `for_each` earns its complexity when keys come and go."

### Things to say before the mentor finds them

**Our images come from Docker Hub, not ECR.** So today the S3 endpoint doesn't help image pulls at all — they still go out through the NAT. The endpoint is there because the design targets ECR, where image layers are stored in S3, and because it's free. Moving to ECR is the next step. There's a real reason to: Docker Hub limits anonymous pulls to 100 per 6 hours per IP, and all our nodes share one NAT IP.

**No ECR/STS/CloudWatch interface endpoints.** They cost about $7/month each. Out of scope on a $20 budget.

**No RAM share.** One account. The comment at the top of `main.tf` says where it would go.

## Module 2 — `eks` (done)

The module already built the cluster: private API endpoint, KMS encryption of secrets, OIDC for pod identity, IAM roles. What it couldn't do was express the three nodegroups on diagram 2. Three changes fixed that:

1. Split the single `subnet_ids` into `cluster_subnet_ids` (for the control-plane ENIs) and a per-nodegroup `subnet_ids`. Every nodegroup lists all three app subnets — that's "every tier spans every AZ."
2. `labels` on each nodegroup — the sign on the door (`role=system`).
3. `taints` on each nodegroup — the lock on the door. `system` gets `CriticalAddonsOnly` so app pods can't crowd CoreDNS. `backend` gets `workload=backend`. `frontend` gets no taint — it's the open pool, so a pod with no placement rules always has somewhere to land.

Labels and taints are `optional()` with empty defaults, so `frontend` doesn't mention taints at all. The taints are emitted with a `dynamic "taint"` block, which produces zero or more blocks from a list.

### Why `backend` is ON_DEMAND, not SPOT

The design says spot, and the module supports it — `capacity_type` is one word in `terraform.tfvars`. This build runs on-demand because the things that make spot safe aren't in place yet:

- no PodDisruptionBudgets, so nothing stops Kubernetes draining below quorum
- one instance type (`t3.small`), so a capacity shortage in one AZ could take the whole tier at once, with nowhere to reschedule

The rule isn't "backend never uses spot" — plenty of production backends do. It's whether the workload tolerates a 2-minute eviction: stateless, replicated, PDB-protected and instance-diverse means yes. Add those three things and this tier moves to spot for roughly a 65% saving on its nodes.

## Root wiring (done)

`module "vpc"` → `module "eks_network"`. Eleven references moved to the new outputs, including five `-target=` addresses in `infra-bootstrap.yaml` that Terraform never validates — only a grep catches those.

The one that matters: the RDS subnet group moved from the app tier to `data_subnet_ids`. That's the moment the three-tier design became real rather than drawn.

New root variables: `app_subnet_cidrs` at `/20`, `data_subnet_cidrs`, `nat_per_az = false`. The single `demo-node-group` became `system`, `frontend`, `backend`.

Nodegroups get their subnets in the root, not in `tfvars`:

```hcl
node_groups = {
  for name, ng in var.node_groups :
  name => merge(ng, { subnet_ids = module.eks_network.app_subnet_ids })
}
```

`tfvars` can't reference a module output, so the root adds the subnet list to every nodegroup. That one expression is "every tier spans every AZ."

`modules/vpc` is still on disk but nothing calls it, so it builds nothing. It should be deleted in its own commit.

## How it was proved

Pushed to PR #21. The pipeline from the previous task planned it — green, and the comment reads:

```
Plan: 97 to add, 0 to change, 0 to destroy.
```

Checked against the diagram:

| Design | Plan |
|---|---|
| 9 subnets, 3 tiers x 3 AZs | `aws_subnet.public` x3, `.app` x3, `.data` x3 |
| Single NAT (`nat_per_az = false`) | 1 `aws_nat_gateway`, 1 `aws_eip` |
| One app route table per AZ, each to its NAT | `aws_route_table.app` x3, each `0.0.0.0/0 -> nat_gateway_id` |
| `rt-public` to the IGW | 1 |
| `rt-data` with no routes | 1, tags only — no route block at all |
| S3 gateway endpoint | 1 |
| Three nodegroups with taints | `system` (taint `CriticalAddonsOnly:NO_SCHEDULE`), `frontend` (none), `backend` (taint `workload=backend`) |
| Nothing destroyed | `0 to destroy` |

Nothing was applied. The environment is still torn down; the plan is the proof.

To see the prod NAT option, set `nat_per_az = true` and push — the same comment shows three NAT gateways and three Elastic IPs, again without applying anything.

## If you only remember four sentences

1. Two modules, two diagram tabs. Every box on the diagram is a resource in the code.
2. `nat_per_az` is the one real decision — one line of `count` gives one NAT or three.
3. The data route table has no routes. That absence is what protects the database.
4. Images are on Docker Hub today, so the S3 endpoint doesn't help pulls yet — ECR is the follow-up, and the Docker Hub rate limit is the reason.

## Known gaps, worth saying before they are found

- **The Kubernetes manifests have no tolerations.** Now that `system` and `backend` are tainted, the Deployments can't land there — everything would crowd onto `frontend`. Each service needs a `nodeSelector` and matching `toleration` before the next bootstrap.
- **`non-prod-stop` / `non-prod-start` scale one nodegroup** via the `EKS_NODEGROUP_NAME` secret. With three nodegroups, two would keep running overnight. Needs a loop over `aws eks list-nodegroups`.
- **`rds.tf` allows 3306 from the whole VPC CIDR**, not from the node security group. The fix is one line: `source_security_group_id` instead of `cidr_blocks`.
- **`modules/vpc` is still on disk**, unused. Should be deleted.

None of these block a green plan. The first two block a healthy cluster.
