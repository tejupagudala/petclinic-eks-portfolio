# kubectl & Kubernetes Cheatsheet

Project context: **Petclinic microservices on EKS**
- Namespace: `petclinic` (app pods)
- Namespace: `monitoring` (Prometheus/Grafana)
- Namespace: `kube-system` (addons like metrics-server, ALB controller)
- Services: api-gateway, customers-service, vets-service, visits-service, genai-service, config-server, discovery-server
- api-gateway uses **Argo Rollouts** (canary), others use **Deployments**

---

## 1. Inspection — "What's running?"

| Command | Example from project | What it does |
|---|---|---|
| `kubectl get pods -n <ns>` | `kubectl get pods -n petclinic` | List all pods in petclinic namespace |
| `kubectl get pods -n <ns> -o wide` | `kubectl get pods -n petclinic -o wide` | Also shows node + pod IP |
| `kubectl get all -n <ns>` | `kubectl get all -n petclinic` | Pods + services + deployments + replicasets |
| `kubectl get nodes` | `kubectl get nodes` | List EKS worker nodes |
| `kubectl get svc -n <ns>` | `kubectl get svc -n petclinic` | Services (including api-gateway root/stable/canary) |
| `kubectl get deploy -n <ns>` | `kubectl get deploy -n petclinic` | Deployments (customers-service, vets-service, etc.) |
| `kubectl get rollout -n <ns>` | `kubectl get rollout api-gateway -n petclinic` | Argo Rollouts resource (only for api-gateway) |
| `kubectl get ns` | `kubectl get ns` | All namespaces — confirms petclinic, monitoring exist |

---

## 2. Debugging — "Why isn't it working?"

| Command | Example | What it does |
|---|---|---|
| `kubectl describe pod <name>` | `kubectl describe pod customers-service-xyz -n petclinic` | Events, last state (OOMKilled!), restart count, node, volumes |
| `kubectl logs <pod>` | `kubectl logs customers-service-xyz -n petclinic` | Current container logs |
| `kubectl logs <pod> --previous` | `kubectl logs customers-service-xyz --previous -n petclinic` | Logs from the last crashed container (for CrashLoopBackOff!) |
| `kubectl logs -f <pod>` | `kubectl logs -f api-gateway-abc -n petclinic` | Follow logs live |
| `kubectl logs -l app=<label>` | `kubectl logs -l app=customers-service -n petclinic` | Logs from all replicas |
| `kubectl get events -n <ns> --sort-by='.lastTimestamp'` | `kubectl get events -n petclinic --sort-by='.lastTimestamp'` | Recent cluster events |

**Golden Rule:** `describe` first, `logs` second.

---

## 3. Resource Monitoring — "Is it starving?"

> Requires **metrics-server** to be installed.

| Command | Example | What it does |
|---|---|---|
| `kubectl top pods -n <ns>` | `kubectl top pods -n petclinic` | CPU/memory per pod — catches OOM risk |
| `kubectl top nodes` | `kubectl top nodes` | Node-level CPU/memory — catches capacity issues |
| `kubectl top pods --containers` | `kubectl top pods -n petclinic --containers` | Break down per container inside pod |

---

## 4. Interacting — "Let me get inside"

| Command | Example | What it does |
|---|---|---|
| `kubectl exec -it <pod> -- sh` | `kubectl exec -it customers-service-xyz -n petclinic -- sh` | Shell into pod |
| `kubectl exec <pod> -- <cmd>` | `kubectl exec api-gateway-abc -n petclinic -- curl localhost:8080/actuator/health` | One-off command |
| `kubectl port-forward svc/<svc> <local>:<remote>` | `kubectl port-forward svc/grafana 3000:80 -n monitoring` | Access Grafana at localhost:3000 |
| `kubectl port-forward svc/prometheus-operated 9090 -n monitoring` | Access Prometheus UI locally |
| `kubectl cp <pod>:<src> <dest>` | `kubectl cp customers-service-xyz:/tmp/heap.log ./heap.log -n petclinic` | Copy files out |

---

## 5. Actions — "Make changes"

| Command | Example | What it does |
|---|---|---|
| `kubectl apply -f <file>` | `kubectl apply -f kubernetes/customers-service/deploy.yaml` | Apply manifest |
| `kubectl apply -f <dir>/` | `kubectl apply -f kubernetes/customers-service/` | Apply all manifests in folder |
| `kubectl delete pod <name>` | `kubectl delete pod customers-service-xyz -n petclinic` | Delete pod (restarts if managed) |
| `kubectl rollout restart deploy/<name>` | `kubectl rollout restart deploy/customers-service -n petclinic` | Restart all pods of a deployment |
| `kubectl rollout status deploy/<name>` | `kubectl rollout status deploy/customers-service -n petclinic` | Watch rollout progress |
| `kubectl rollout undo deploy/<name>` | `kubectl rollout undo deploy/customers-service -n petclinic` | Roll back to previous version |
| `kubectl scale deploy <name> --replicas=N` | `kubectl scale deploy customers-service --replicas=3 -n petclinic` | Change replica count |
| `kubectl edit deploy <name>` | `kubectl edit deploy customers-service -n petclinic` | Edit live (opens in vim) |

---

## 6. Context & Config — "Where am I?"

| Command | Example | What it does |
|---|---|---|
| `kubectl config current-context` | `kubectl config current-context` | Which cluster you're pointing to |
| `kubectl config get-contexts` | List all clusters configured |
| `kubectl config use-context <name>` | Switch between clusters |
| `kubectl config set-context --current --namespace=<ns>` | `kubectl config set-context --current --namespace=petclinic` | Default to petclinic — no more typing `-n petclinic` |
| `aws eks update-kubeconfig --name <cluster> --region <region>` | `aws eks update-kubeconfig --name petclinic-eks --region us-east-1` | Get kubeconfig for EKS cluster |

---

## 7. Argo Rollouts — api-gateway Canary

| Command | Example | What it does |
|---|---|---|
| `kubectl argo rollouts get rollout <name>` | `kubectl argo rollouts get rollout api-gateway -n petclinic` | Rollout status (with `-w` to watch) |
| `kubectl argo rollouts promote <name>` | `kubectl argo rollouts promote api-gateway -n petclinic` | Manually promote paused canary |
| `kubectl argo rollouts abort <name>` | `kubectl argo rollouts abort api-gateway -n petclinic` | Abort and rollback |
| `kubectl argo rollouts set image <name> <container>=<image>` | Update image without editing YAML |

---

## 8. Advanced — For Senior Roles

| Command | Example | What it does |
|---|---|---|
| `kubectl auth can-i <verb> <resource>` | `kubectl auth can-i create pods -n petclinic` | Check RBAC |
| `kubectl explain <resource>.<field>` | `kubectl explain pod.spec.containers.resources` | Inline docs |
| `kubectl debug <pod> -it --image=busybox` | `kubectl debug api-gateway-abc -it --image=busybox -n petclinic` | Ephemeral debug container |
| `kubectl get pod <name> -o yaml` | `kubectl get pod customers-service-xyz -n petclinic -o yaml` | Full YAML spec |
| `kubectl diff -f <file>` | `kubectl diff -f kubernetes/customers-service/deploy.yaml` | Preview what would change |
| `kubectl get pods -o jsonpath='{.items[*].metadata.name}'` | Scriptable output |

---

## 9. Common Diagnostic Workflows

### Scenario A: Pod is CrashLoopBackOff
```bash
kubectl describe pod <name> -n petclinic          # 1. Check Last State + Events
kubectl logs <name> --previous -n petclinic       # 2. Logs from the crashed container
kubectl get events -n petclinic --sort-by='.lastTimestamp'  # 3. Cluster-wide context
```

### Scenario B: Pod is Pending (not scheduling)
```bash
kubectl describe pod <name> -n petclinic          # Events show "Insufficient cpu/memory" or "PVC not bound"
kubectl top nodes                                  # Are all nodes full?
kubectl get nodes                                  # Are any nodes NotReady?
```

### Scenario C: ImagePullBackOff
```bash
kubectl describe pod <name> -n petclinic          # Events show auth error or "manifest not found"
# Usually → wrong tag in deploy.yaml OR missing imagePullSecret
```

### Scenario D: Pod Running but 500 errors
```bash
kubectl logs <name> -n petclinic                  # App-level exception (DB down, bad config)
kubectl exec <name> -n petclinic -- curl localhost:8080/actuator/health   # Direct health check
```

### Scenario E: Canary rollout stuck
```bash
kubectl argo rollouts get rollout api-gateway -n petclinic -w
kubectl argo rollouts status api-gateway -n petclinic
kubectl describe analysisrun -n petclinic         # Check if Prometheus analysis failed
```

---

## 10. The 5 Commands to Know Cold

1. **`kubectl get pods -n petclinic`** — what's running
2. **`kubectl describe pod <name>`** — why it's broken
3. **`kubectl logs <name> --previous`** — what crashed
4. **`kubectl top pods`** — is it starving (needs metrics-server)
5. **`kubectl exec -it <pod> -- sh`** — jump inside

---

## Quick Reference: Symptom → First Command

| Symptom | First command |
|---|---|
| Pod CrashLoopBackOff | `kubectl describe pod` → check `Last State` |
| Pod ImagePullBackOff | `kubectl describe pod` → check `Events` |
| Pod OOMKilled | `kubectl describe pod` → `Exit Code: 137` |
| Pod Pending | `kubectl describe pod` → `Events: Insufficient...` |
| Pod Running but broken | `kubectl logs` → app exception |
| Grafana not accessible | `kubectl port-forward svc/grafana -n monitoring 3000:80` |
| Need to restart app | `kubectl rollout restart deploy/<name>` |
| Need to roll back | `kubectl rollout undo deploy/<name>` |
| Canary broken | `kubectl argo rollouts abort api-gateway -n petclinic` |
