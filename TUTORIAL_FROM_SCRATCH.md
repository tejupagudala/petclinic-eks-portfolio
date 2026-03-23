# Petclinic From-Scratch Tutorial (Full Build + Observability)

This is the start-to-finish tutorial to rebuild this project after a fresh `terraform destroy`.

Goal:

- Run Petclinic microservices on EKS
- Expose app through ALB ingress
- Enable observability for:
  - application metrics
  - Kubernetes metrics
  - infrastructure/container metrics
- Validate everything from localhost

## 1) Project architecture in this repo

Core app services (Kubernetes manifests):

- `kubernetes/mysql/*`
- `kubernetes/config-server/*`
- `kubernetes/discovery-server/*`
- `kubernetes/customers-service/*`
- `kubernetes/visits-service/*`
- `kubernetes/vets-service/*`
- `kubernetes/api-gateway/*`

Infra:

- `terraform/*`

Kubernetes observability:

- `kubernetes/monitoring/petclinic-servicemonitor.yml`
- `kubernetes/monitoring/README.md`

Local Docker observability:

- `app/docker-compose.yml`
- `app/docker/prometheus/*`
- `app/docker/grafana/*`
- `app/docker/OBSERVABILITY.md`

## 2) Prerequisites

Install:

- `aws`
- `terraform`
- `kubectl`
- `helm`
- `eksctl`
- `docker`

Set environment:

```bash
export AWS_PROFILE=myaccount
export AWS_REGION=us-east-1
export ACCOUNT_ID=479407618698
aws sts get-caller-identity
```

Why:

- Every later step depends on these tools and AWS auth.

## 3) Provision AWS infrastructure

```bash
cd terraform
terraform init -input=false
terraform apply -auto-approve
```

Then configure kubeconfig:

```bash
cd ..
aws eks update-kubeconfig --name demo-eks-cluster --region us-east-1 --profile myaccount
kubectl get nodes
```

Why:

- Creates VPC, EKS cluster, node group, networking required by workloads.

## 4) Install AWS Load Balancer Controller (required for ingress)

Associate OIDC:

```bash
eksctl utils associate-iam-oidc-provider --cluster demo-eks-cluster --region us-east-1 --approve
```

Create IAM policy (from repo root `iam_policy.json`):

```bash
POLICY_ARN=$(aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json \
  --query 'Policy.Arn' \
  --output text 2>/dev/null || true)
[ -z "$POLICY_ARN" ] || [ "$POLICY_ARN" = "None" ] && POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
echo "$POLICY_ARN"
```

Create/refresh IAM service account:

```bash
eksctl create iamserviceaccount \
  --cluster demo-eks-cluster \
  --region us-east-1 \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn "$POLICY_ARN" \
  --approve \
  --override-existing-serviceaccounts
```

Install controller:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

VPC_ID=$(aws ec2 describe-vpcs --filters Name=tag:Name,Values=demo-eks-cluster-vpc --query 'Vpcs[0].VpcId' --output text)

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=demo-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=us-east-1 \
  --set vpcId="$VPC_ID"

kubectl -n kube-system rollout status deploy/aws-load-balancer-controller
```

Why:

- Without this controller, ALB ingress never gets an external address.

## 5) Deploy application workloads

```bash
kubectl create namespace petclinic --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f kubernetes/mysql/
kubectl apply -f kubernetes/discovery-server/
kubectl apply -f kubernetes/config-server/
kubectl apply -f kubernetes/customers-service/
kubectl apply -f kubernetes/visits-service/
kubectl apply -f kubernetes/vets-service/
kubectl apply -f kubernetes/api-gateway/
```

Verify:

```bash
kubectl get pods -n petclinic
kubectl get svc -n petclinic
kubectl get ingress -n petclinic -o wide
```

Why:

- This brings up the full backend and ingress entrypoint.

## 6) Important app config files and why they were changed

### `kubernetes/customers-service/deploy.yaml`
### `kubernetes/visits-service/deploy.yaml`
### `kubernetes/vets-service/deployment.yaml`

Required env keys:

- `SPRING_CONFIG_IMPORT=optional:configserver:http://config-server.petclinic.svc.cluster.local:8888/`
- `SPRING_CLOUD_CONFIG_ENABLED=true`
- `SPRING_CLOUD_CONFIG_URI=http://config-server.petclinic.svc.cluster.local:8888`
- `MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health,info,prometheus`

Why:

- Fixes startup failures against config server.
- Enables `/actuator/prometheus` scraping.

If missing:

- pods can crash (`ConfigClientFailFastException`) and app metrics are unavailable.

## 7) Validate app API externally through ingress

Wait until ingress has `ADDRESS`:

```bash
kubectl -n petclinic get ingress frontend-proxyr -w
```

Test API:

```bash
ALB=$(kubectl -n petclinic get ingress frontend-proxyr -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -i -H "Host: petclinic.local" "http://$ALB/api/customer/owners"
curl -i -H "Host: petclinic.local" "http://$ALB/api/vet/vets"
```

Map local domain:

```bash
nslookup "$ALB"
# choose a returned IP
echo "<ALB_IP> petclinic.local" | sudo tee -a /etc/hosts
curl -i http://petclinic.local/api/customer/owners
```

Note:

- API paths work at `/api/*`.
- Root `/` behavior can vary by image/build; validate APIs first.

## 8) Kubernetes observability (Prometheus + Grafana + ServiceMonitor)

Install stack:

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring
kubectl get pods -n monitoring
```

Apply application ServiceMonitors:

```bash
kubectl apply -f kubernetes/monitoring/petclinic-servicemonitor.yml
kubectl get servicemonitor -n monitoring
```

Port-forward:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# if 3000 is busy:
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3001:80
```

Validate categories in Prometheus (`http://localhost:9090`):

Infrastructure:

```promql
count(node_uname_info)
```

Kubernetes:

```promql
count(kube_pod_info{namespace="petclinic"})
```

Container:

```promql
sum(rate(container_cpu_usage_seconds_total{namespace="petclinic",container!="",container!="POD"}[5m])) by (pod)
```

Application:

```promql
up{job=~"api-gateway|customers-service|visits-service|vets-service"}
```

Why:

- This is the complete metrics pipeline for cluster + app.

## 9) Local Docker observability (separate from Kubernetes)

Use this when you want local-only observability without EKS:

- Follow [app/docker/OBSERVABILITY.md](/Users/sai/petclinic-eks-portfolio-1/app/docker/OBSERVABILITY.md)

Includes:

- `docker compose` startup
- Prometheus at `localhost:9091`
- Grafana at `localhost:3030`
- local app metrics validation and troubleshooting

## 10) Troubleshooting Log (Issues Faced + Fixes)

Use this as quick reference when re-running from scratch.

| # | Symptom | Root cause | Fix applied |
|---|---|---|---|
| 1 | `UnknownHostException: config-server` and startup failure | Service configs were mixed between config-server mode and Kubernetes-native mode | Standardized startup config to one mode per service. For Kubernetes-native mode: `SPRING_CLOUD_CONFIG_ENABLED=false`, load from ConfigMap, use Kubernetes DNS service names. |
| 2 | `customers/visits/vets` pods in `CrashLoopBackOff` right after deploy | App containers started before MySQL was ready | Added `initContainers` waiting on `mysql:3306` (busybox + `nc`). |
| 3 | `visits-service` crashed while dependencies looked healthy | Visits started before `customers-service` API was ready | Added second init container in visits deployment to wait for `http://customers-service:8081/actuator/health`. |
| 4 | Ingress had empty `ADDRESS` for a long time | AWS Load Balancer Controller not installed | Installed controller via Helm in `kube-system`. |
| 5 | ALB controller deployment existed but `0/2` and no pods | Missing/invalid service account linkage | Created `aws-load-balancer-controller` service account and annotated with IAM role ARN. |
| 6 | Ingress events showed `AssumeRoleWithWebIdentity` `403 AccessDenied` | IAM role trust policy pointed to wrong EKS OIDC provider id | Rebuilt IAM trust policy to match current cluster OIDC issuer and SA subject `system:serviceaccount:kube-system:aws-load-balancer-controller`. |
| 7 | Helm install command failed with shell parse errors | Placeholder values (`<...>`) and malformed multiline command | Resolved real values first (`VPC_ID`, account id) and re-ran clean command. |
| 8 | ALB hostname from ingress did not resolve on laptop (`curl: Could not resolve host`) | Local DNS resolver inconsistency | Verified ALB with `nslookup`/`dig`, then mapped one ALB IP in `/etc/hosts` for `petclinic.local`. |
| 9 | `404` on root path while `/api/...` worked | This deployment exposes backend APIs only; no separate frontend UI pod/service | Validated success using `/api/customer/...`, `/api/vet/...`, `/api/visit/...`. (UI deployment is a separate future step.) |
| 10 | `Application` kind not found when applying Argo app YAML | Argo CD CRDs/controllers were not installed yet | Installed Argo CD first, then applied `kubernetes/argocd/*` manifests. |
| 11 | `error: path does not exist` for ServiceMonitor | Wrong filename used (`...servicemonitors.yaml`) | Used the exact repo file: `kubernetes/monitoring/petclinic-servicemonitor.yml`. |
| 12 | Prometheus query parse errors like `unexpected <aggr:count>` | Multiple PromQL expressions pasted together | Entered exactly one query at a time per query box. |
| 13 | Terraform anomaly monitor create failed (`Limit exceeded on dimensional spend monitor creation`) | AWS account already had max dimensional anomaly monitors | Added support to reuse existing monitor via `-var="existing_anomaly_monitor_arn=..."`. |
| 14 | Terraform anomaly subscription schema errors (`threshold`, subscriber blocks) | Terraform block syntax did not match provider schema | Updated anomaly subscription to valid `threshold_expression` and daily email subscriber format. |
| 15 | Terraform apply failed with state lock errors (`PreconditionFailed`) | Existing stale/in-use lock in remote state | Released lock and reran apply (`terraform force-unlock <LOCK_ID>` when safe). |
| 16 | GitHub Actions OIDC failures after `terraform destroy` | IAM role used by workflows was deleted with infra | Expected behavior. Re-apply Terraform first, then update GitHub secrets with fresh output values. |
| 17 | Cost report workflow failed with jq syntax error | jq string-format expression incompatibility in runner | Reworked formatting pipeline to `jq -> tsv -> awk` and re-tested workflow. |
| 18 | `terraform apply` said `No configuration files` | Command executed from wrong folder | Ran with `terraform -chdir=terraform ...` or from inside `terraform/`. |
| 19 | Main infra destroyed but billing artifacts still existed | Backend stack (`terraform/backend`) is separate | Destroyed backend stack separately when full teardown was required. |

## 11) Cost-saving alternatives to full destroy

1. Scale app + monitoring workloads to 0, keep cluster.
2. Scale node group desired/min to 0 for bigger savings.
3. Full `terraform destroy` for max savings.

Use full destroy only when you are pausing for longer periods.

## 12) Final validation checklist

- `kubectl get pods -n petclinic` => all running
- `kubectl get ingress -n petclinic` => ADDRESS present
- `/api/customer/owners` responds `200`
- `kubectl get pods -n monitoring` => Prometheus/Grafana running
- Prometheus queries return infra + k8s + container + app metrics
- Grafana dashboards show live data


command for vpc id retriveal :

AWS_PROFILE=myaccount aws ec2 describe-vpcs \
  --filters Name=tag:Name,Values=demo-eks-cluster-vpc \
  --region us-east-1 \
  --query 'Vpcs[0].VpcId' \
  --output text
