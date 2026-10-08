# Rebuild and teardown runbook

How to stand this platform up from an empty AWS account and tear it back
down without stranding billable resources.

The cluster is destroyed between working sessions, so this path gets used
often. Most of it is automated; the manual steps below are gaps that have
not been automated yet, listed in [Known gaps](#known-gaps).

---

## Bring it up

### 1. Check your public IP

The EKS API server is allowlisted to a single `/32`. Home IPs get
reassigned, and a stale CIDR locks you out of `kubectl` with an i/o
timeout (the bootstrap workflow still works, because the private endpoint
is enabled and the runner is inside the VPC).

```bash
curl -s https://checkip.amazonaws.com
```

If it differs from `eks_public_access_cidrs` in `terraform/terraform.tfvars`,
update that value and merge before continuing.

### 2. Run the bootstrap

```bash
gh workflow run infra-bootstrap.yaml --ref main
```

Roughly 25 minutes. Must run from `main` — the infra OIDC role trusts only
`repo:<org>/<repo>:ref:refs/heads/main`, so dispatching from a feature
branch fails at *Configure AWS credentials* with
`Not authorized to perform sts:AssumeRoleWithWebIdentity`.

This creates the VPC and subnets, the EKS cluster, all four node groups
with their labels and taints, RDS, OIDC/IRSA, then installs the AWS Load
Balancer Controller, Argo CD, Argo Rollouts and kube-prometheus-stack, and
finally applies the Petclinic manifests and runs readiness checks.

### 3. Grant yourself cluster access

The cluster grants admin to its creator — the GitHub Actions infra role —
not to your IAM user. Without an access entry, `kubectl` authenticates and
then returns `Forbidden`.

```bash
aws eks create-access-entry --cluster-name demo-eks-cluster --region us-east-1 \
  --principal-arn arn:aws:iam::<account>:user/<your-user> --type STANDARD

aws eks associate-access-policy --cluster-name demo-eks-cluster --region us-east-1 \
  --principal-arn arn:aws:iam::<account>:user/<your-user> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster

aws eks update-kubeconfig --name demo-eks-cluster --region us-east-1
```

Both commands are needed: the first says *who may authenticate*, the second
*what they may do*. The policy ARN is in the `arn:aws:eks::aws:cluster-access-policy/`
namespace, **not** `arn:aws:iam::aws:policy/` — using the IAM form returns
`InvalidParameterException: The policyArn parameter format is not valid`.

### 4. Install the ECK stack

Not yet part of the bootstrap.

```bash
helm repo add elastic https://helm.elastic.co
helm install elastic-operator elastic/eck-operator \
  --version 3.5.0 -n elastic-system --create-namespace

kubectl apply -f kubernetes/elastic/
```

The operator must be running before the manifests apply, or they fail with
`no matches for kind "Elasticsearch"`.

### 5. Verify

```bash
kubectl get nodes -L role
kubectl get pods -A --field-selector=status.phase=Pending   # expect none
kubectl get pods -n petclinic -o wide
```

An empty Pending list is the signal that every `nodeSelector` and taint
agrees. Anything stuck there, see [Pods stuck Pending](#pods-stuck-pending).

---

## Tear it down

### 1. Delete ingresses first

```bash
kubectl delete ingress --all -A --ignore-not-found
```

**Do not skip this.** The AWS Load Balancer Controller creates ALBs from
Ingress objects, so those ALBs live in Kubernetes, not Terraform state.
Destroying the cluster kills the controller before it can clean up, leaving
orphaned ALBs that hold ENIs in the subnets and public IPs on the internet
gateway. `terraform destroy` then fails:

```
DependencyViolation: The subnet has dependencies and cannot be deleted
DependencyViolation: Network vpc-... has some mapped public address(es)
```

Deleting the ingresses first lets the controller remove its own load
balancers while it is still alive.

### 2. Destroy

```bash
gh workflow run infra-destroy.yaml --ref main -f confirm=DESTROY
```

The `confirm=DESTROY` input is required; the job is skipped without it.

### 3. Verify nothing is left billing

The workflow's own check only looks at the cluster and runner instances, so
sweep directly:

```bash
R=us-east-1
aws eks list-clusters --region $R --query 'length(clusters)'
aws ec2 describe-instances --region $R \
  --filters "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'length(Reservations[].Instances[])'
aws ec2 describe-nat-gateways --region $R \
  --filter "Name=state,Values=pending,available" --query 'length(NatGateways)'
aws ec2 describe-addresses --region $R --query 'length(Addresses)'
aws rds describe-db-instances --region $R --query 'length(DBInstances)'
aws elbv2 describe-load-balancers --region $R --query 'length(LoadBalancers)'
```

All should be `0`. NAT gateways, Elastic IPs and load balancers are the
ones that bill quietly after a partial teardown.

Customer-managed KMS keys enter a 7-day `PendingDeletion` window and bill
~$1/month each until they disappear. That cannot be shortened, and
cancelling deletion only makes it worse.

---

## Account constraints

This account is on **AWS's restricted Free Tier plan**, which rejects
`RunInstances` for any instance type that is not free-tier eligible:

```
Client.InvalidParameterCombination
The specified instance type is not eligible for Free Tier.
```

The failure mode is unhelpful: the node group sits in `CREATING` for ~25
minutes with no Auto Scaling group and no health issue, then fails with
`AsgInstanceLaunchFailures`. It looks like a quota or capacity problem and
is not — check CloudTrail for the real error.

Eligible types, and the ceiling:

| Type | vCPU | Memory |
|---|---|---|
| `m7i-flex.large` | 2 | **8 GiB — the maximum** |
| `c7i-flex.large` | 2 | 4 GiB |
| `t3`/`t4g`/`t8i.small` | 2 | 2 GiB |
| `t3`/`t4g`/`t8i.micro` | 2 | 1 GiB |

To list them yourself:

```bash
aws ec2 describe-instance-types --region us-east-1 \
  --filters "Name=free-tier-eligible,Values=true" \
  --query 'InstanceTypes[].[InstanceType,MemoryInfo.SizeInMiB]' --output text
```

**There is no node larger than 8 GiB available.** Scale out, not up.

RDS is constrained too. `db.t4g.micro` has had no orderable options for
MySQL in us-east-1, which surfaces as
`InsufficientDBInstanceCapacity ... try the request again at a later time`
— misleading, because retrying never helps. Check before changing class:

```bash
aws rds describe-orderable-db-instance-options --engine mysql \
  --db-instance-class db.t3.micro --region us-east-1 \
  --query 'length(OrderableDBInstanceOptions)'
```

---

## Node group layout

| Group | Type | Capacity | Label | Taint |
|---|---|---|---|---|
| system | t3.small ×2 | ON_DEMAND | `role=system` | `CriticalAddonsOnly=true` |
| frontend | t3.small ×2 | ON_DEMAND | `role=frontend` | **none** |
| backend | t3.small ×2 | SPOT | `role=backend` | `workload=backend` |
| observability | m7i-flex.large ×1 | ON_DEMAND | `role=observability` | `workload=observability` |

`frontend` is deliberately untainted. Helm hook Jobs — the
kube-prometheus-stack admission-webhook patch, Argo CD's redis-secret-init —
ship without tolerations, so a fully tainted cluster hangs every
`helm --wait` install. One untainted pool absorbs them.

The cost of that choice: **every unpinned pod lands on `frontend`**, and a
t3.small holds only 11 pods (3 ENIs × 4 IPv4 each). Argo CD's seven
components plus the monitoring stack's five once filled both frontend nodes
and left api-gateway unschedulable. Both charts are now pinned to
`observability` via `kubernetes/helm-values/`.

Anything added to the cluster later needs a deliberate home, or it lands on
`frontend` and eats that headroom.

---

## Troubleshooting

### Pods stuck Pending

```bash
kubectl get pods -A --field-selector=status.phase=Pending
kubectl describe pod <name> -n <ns> | grep -A6 Events:
```

Read the scheduler message carefully — the two causes look similar but are
not:

- `Too many pods` — the node hit its IPv4/ENI pod ceiling. Pin something
  else away, or add a node. More memory does not help.
- `untolerated taint` — the pod lacks a toleration for the group it is
  targeting, or has no `nodeSelector` and every node is tainted.

Node headroom:

```bash
kubectl describe node <node> | grep -A6 "Allocated resources"
kubectl get node <node> -o jsonpath='{.status.allocatable.pods}{"\n"}'
```

### Helm values rejected by kubectl

Several steps apply whole directories (`kubectl apply -f kubernetes/argocd/`).
A Helm values file placed in one of those directories gets caught by the
glob:

```
error validating "...": [apiVersion not set, kind not set]
```

Values files belong in `kubernetes/helm-values/`, never beside manifests.

### Terraform state lock after a cancelled run

Cancelling a workflow mid-apply leaves the lock held:

```
Error acquiring the state lock ... PreconditionFailed
```

Prefer letting a doomed apply fail on its own — Terraform then releases the
lock cleanly. If a lock is genuinely stranded, take the ID from the error
and confirm the holding run is no longer active before forcing:

```bash
terraform -chdir=terraform force-unlock -force <LOCK_ID>
```

### PR plan check fails on AccessDenied

The plan role uses a hand-scoped read policy in
`terraform/github_plan_role.tf`, so a resource type it has never seen will
fail the refresh once that resource exists:

```
is not authorized to perform: <action>
```

Add the action to the matching statement. Because the fix cannot plan
itself, that one PR needs `gh pr merge <n> --admin`, then an apply to make
the policy live.

### Node group stuck in CREATING

Check CloudTrail rather than guessing at quotas:

```bash
aws cloudtrail lookup-events --region us-east-1 \
  --lookup-attributes AttributeKey=EventName,AttributeValue=RunInstances \
  --max-results 15 --query 'Events[].CloudTrailEvent' --output text
```

The `errorMessage` field carries the real reason. Quota, AZ availability
and subnet IP capacity are all worth measuring before assuming:

```bash
aws service-quotas get-service-quota --service-code ec2 \
  --quota-code L-1216C47A --region us-east-1 --query 'Quota.Value'
aws ec2 describe-instance-type-offerings --location-type availability-zone \
  --filters "Name=instance-type,Values=<type>" --region us-east-1 \
  --query 'InstanceTypeOfferings[].Location'
```

---

## Known gaps

Automating these turns the four-step rebuild into one command.

| Gap | Impact | Fix |
|---|---|---|
| ECK operator and stack are manual | Steps 4 above, and the 3.5.0 version is recorded nowhere else | Helm install pinned to 3.5.0 plus an apply step in `infra-bootstrap` |
| Cluster access entry is manual | `kubectl` returns `Forbidden` after every rebuild | `aws_eks_access_entry` resource in Terraform |
| No ingress cleanup on teardown | Strands ALBs and Elastic IPs, fails the destroy | `kubectl delete ingress --all -A` step in `infra-destroy` |
| CoreDNS has no `nodeSelector` | Both replicas drift onto `frontend`, the most crowded group | `aws_eks_addon` for coredns with `configuration_values` |
| `non-prod-stop`/`start` target one group | `EKS_NODEGROUP_NAME` matches none of the four names, so nightly scale-down covers nothing | Iterate `aws eks list-nodegroups` |
| `eks_public_access_cidrs` set in two places | `terraform.tfvars` outranks `TF_VAR_*` env vars, so the `EKS_PUBLIC_ACCESS_CIDR` secret is silently ignored | Pick one source of truth |
