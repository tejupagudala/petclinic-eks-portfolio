# Kubernetes Observability Runbook (Petclinic)

This guide is the exact sequence to bring observability up from scratch after recreating the cluster.

Scope:

- Infrastructure metrics
- Container metrics
- Application metrics
- Local access on `localhost` for Prometheus and Grafana

## 1) Prerequisites

Run from repo root with working kubeconfig:

```bash
export AWS_PROFILE=myaccount
export AWS_REGION=us-east-1
kubectl get nodes
kubectl get ns
```

Why:

- Metrics stack and ServiceMonitors are Kubernetes resources.

If skipped:

- You can apply manifests to the wrong cluster/context.

## 2) Verify app stack is healthy before observability

```bash
kubectl get pods -n petclinic
kubectl get svc -n petclinic
```

Expect all petclinic pods `Running`.

Why:

- Prometheus cannot scrape app metrics from crashed pods.

If skipped:

- You get empty app metrics and misdiagnose observability as broken.

## 3) Install kube-prometheus-stack (infra + container + k8s metrics)

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring
```

Verify:

```bash
kubectl get pods -n monitoring
kubectl get servicemonitor -n monitoring
```

Why:

- This installs Prometheus Operator, Prometheus, Grafana, node-exporter, kube-state-metrics.

If skipped:

- No infrastructure or container metrics in cluster.

## 4) Ensure app deployments expose Prometheus endpoint

Check these in petclinic app deployments (`customers`, `visits`, `vets`, `api-gateway`):

- `MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE` contains `prometheus`

Quick check:

```bash
kubectl -n petclinic get deploy customers-service -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' | grep MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
kubectl -n petclinic get deploy visits-service -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' | grep MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
kubectl -n petclinic get deploy vets-service -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' | grep MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
kubectl -n petclinic get deploy api-gateway -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}' | grep MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE
```

Why:

- `/actuator/prometheus` must be exposed for scraping.

If skipped:

- `up{job="..."}` for app services stays `0` or jobs do not appear.

## 5) Apply ServiceMonitors (application metrics discovery)

Apply the existing file in this repo:

```bash
kubectl apply -f kubernetes/monitoring/petclinic-servicemonitor.yml
kubectl get servicemonitor -n monitoring
```

Important filename:

- `petclinic-servicemonitor.yml` (singular, `.yml`)

Why:

- Prometheus Operator discovers app scrape targets via ServiceMonitor CRDs.

If skipped:

- You only get infra/container metrics, not app metrics.

## 6) Port-forward for local access (localhost)

Prometheus:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Grafana (default):

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

If `3000` is already used, run Grafana on `3001`:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3001:80
```

Why:

- Gives local UI access without exposing monitoring services publicly.

If skipped:

- You cannot validate via browser at `localhost`.

## 7) Validate metrics by category

Open Prometheus at `http://localhost:9090`.

### 7.1 Infrastructure (node) metrics

```promql
count(node_uname_info)
sum(rate(node_cpu_seconds_total{mode!="idle"}[5m])) by (instance)
```

### 7.2 Kubernetes state metrics

```promql
count(kube_node_info)
count(kube_pod_info{namespace="petclinic"})
sum(kube_deployment_status_replicas_available{namespace="petclinic"}) by (deployment)
```

### 7.3 Container runtime metrics

```promql
sum(rate(container_cpu_usage_seconds_total{namespace="petclinic",container!="",container!="POD"}[5m])) by (pod)
sum(container_memory_working_set_bytes{namespace="petclinic",container!="",container!="POD"}) by (pod)
```

### 7.4 Application metrics

```promql
up{job=~"api-gateway|customers-service|visits-service|vets-service"}
sum(rate(http_server_requests_seconds_count{job=~"api-gateway|customers-service|visits-service|vets-service"}[5m])) by (job,status)
sum(jvm_memory_used_bytes{job=~"api-gateway|customers-service|visits-service|vets-service",area="heap"}) by (job)
```

Why:

- Confirms each layer is observable independently.

If skipped:

- You cannot tell whether failure is app-level or platform-level.

## 8) Generate traffic for meaningful app charts

```bash
ALB=$(kubectl -n petclinic get ingress frontend-proxyr -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

for i in {1..30}; do curl -s -H "Host: petclinic.local" "http://$ALB/api/customer/owners" >/dev/null; done
for i in {1..30}; do curl -s -H "Host: petclinic.local" "http://$ALB/api/vet/vets" >/dev/null; done
for i in {1..30}; do curl -s -H "Host: petclinic.local" "http://$ALB/api/visit/owners/1/pets/1/visits" >/dev/null; done
```

Why:

- Request-rate and latency metrics stay near zero without traffic.

If skipped:

- Dashboards look empty even when setup is correct.

## 9) Grafana setup and dashboard grouping

Open Grafana:

- `http://localhost:3000` (or `http://localhost:3001` if remapped)

Get admin password:

```bash
kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Create 3 folders and dashboards:

- `Application`
- `Kubernetes`
- `Infrastructure`

Use panel queries from section 7.

Why:

- Separation keeps troubleshooting fast and consistent.

If skipped:

- Metrics are available but operational visibility is fragmented.

## 10) Known issues and fixes (from this project)

### 10.1 `CrashLoopBackOff` on app pods with config import errors

Error:

- `Unable to load config data from 'configserver:http://config-server:8888'`

Fix in app deployments:

- `SPRING_CLOUD_CONFIG_ENABLED=true`
- `SPRING_CONFIG_IMPORT=optional:configserver:http://config-server.petclinic.svc.cluster.local:8888/`
- `SPRING_CLOUD_CONFIG_URI=http://config-server.petclinic.svc.cluster.local:8888`

Then restart deployments.

### 10.2 Ingress has no ADDRESS with `AssumeRoleWithWebIdentity` 403

Fix:

- Validate ALB controller service account annotation and IAM role trust policy.
- Restart controller and recreate ingress.

Check:

```bash
kubectl -n kube-system get sa aws-load-balancer-controller -o yaml
kubectl -n kube-system logs deploy/aws-load-balancer-controller --tail=200
kubectl describe ingress frontend-proxyr -n petclinic
```

### 10.3 ServiceMonitor apply path error

If you see `path does not exist`, use exact file name:

```bash
kubectl apply -f kubernetes/monitoring/petclinic-servicemonitor.yml
```

### 10.4 Prometheus query parse error (`unexpected <aggr:count>`)

Cause:

- multiple queries pasted into one query box.

Fix:

- run one PromQL expression at a time.

### 10.5 Grafana port-forward fails on `3000` already in use

Fix:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3001:80
```

## 11) Recreate-from-scratch checklist (destroy/apply safe)

After `terraform destroy` and fresh `terraform apply`, run in order:

1. Configure kubeconfig (`aws eks update-kubeconfig`)
2. Install/verify ALB controller and IRSA
3. Deploy petclinic manifests
4. Verify all petclinic pods `Running`
5. Install/verify kube-prometheus-stack
6. Apply `kubernetes/monitoring/petclinic-servicemonitor.yml`
7. Port-forward Prometheus/Grafana to localhost
8. Run validation queries for infra/k8s/container/app metrics

If every step passes, you avoid all issues encountered today.
