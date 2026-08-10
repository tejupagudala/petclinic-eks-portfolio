# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spring Boot microservices (Petclinic) deployed on AWS EKS with Terraform IaC, GitHub Actions CI/CD, Argo Rollouts canary deployments, and a full observability stack (Prometheus/Grafana).

## Build & Test Commands

All Maven commands run from `app/` directory using the wrapper (`./mvnw`).

```bash
# Full build (skip tests)
cd app && ./mvnw clean package -DskipTests

# Build a single service (with dependencies)
cd app && ./mvnw -pl spring-petclinic-api-gateway -am clean package -DskipTests

# Run tests for a single service
cd app && ./mvnw -pl spring-petclinic-customers-service -am test

# Build Docker images (requires Docker running)
cd app && ./mvnw -pl spring-petclinic-api-gateway -PbuildDocker clean install

# Local dev with Docker Compose
cd app && ./mvnw clean package -DskipTests && docker compose up
```

## Architecture

### Microservices (Java 17, Spring Boot 4.0.1, Spring Cloud 2025.1.0)

All services live under `app/spring-petclinic-*/`:

| Service | Port | Role |
|---------|------|------|
| api-gateway | 8080 | Spring Cloud Gateway, routes to all backends. Uses **Argo Rollouts** for canary deployment. |
| discovery-server | 8761 | Eureka service registry |
| config-server | 8888 | Spring Cloud Config |
| customers-service | 8081 | Owners and pets CRUD |
| vets-service | 8083 | Veterinarians data |
| visits-service | 8082 | Visit records |
| genai-service | 8084 | GenAI integration |

Services share a parent POM (`app/pom.xml`) and a common Dockerfile (`app/docker/Dockerfile`) using multi-stage build with `eclipse-temurin:17`.

### Kubernetes Manifests (`kubernetes/`)

Each service has `deploy.yaml`, `service.yaml`, `configmap.yaml` in its own subdirectory. The api-gateway is an **Argo Rollout** (not a Deployment) with canary strategy, analysis template, and three services (root/stable/canary). All other services are standard Deployments.

- Namespace: `petclinic`
- Monitoring namespace: `monitoring` (kube-prometheus-stack Helm chart)
- Ingress: AWS ALB via `kubernetes/api-gateway/ingress.yaml`
- Pod security: non-root (uid 1000), read-only rootfs, seccomp, dropped capabilities

### Terraform (`terraform/`)

Modules in `terraform/modules/`:
- **vpc**: 10.0.0.0/16 CIDR, 3 AZs (us-east-1), single NAT gateway
- **eks**: Kubernetes 1.33, spot t3.small nodes, OIDC/IRSA, private API endpoint

Root-level resources:
- `rds.tf`: MySQL 8.0 on db.t4g.micro
- `cost_guardrails.tf`: $20/month budget, per-service budgets, anomaly detection, SNS alerts
- `github_runner.tf`: Self-hosted EC2 runner for GitHub Actions

Backend: S3 (`terraform-demo-eks-state-lock-bucket`) with KMS encryption.

## CI/CD Workflows (`.github/workflows/`)

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yaml` | PR/push to main | Build, test, SonarCloud, Trivy scan, Docker push, update k8s image tag |
| `infra-bootstrap.yaml` | Manual | Terraform apply, install Argo Rollouts + monitoring + ALB controller |
| `api-gateway-canary.yaml` | Push to main | Canary deploy: 20% traffic → Prometheus analysis → manual approval → promote |
| `e2e-smoke.yaml` | After infra-bootstrap | API endpoint smoke tests |
| `non-prod-stop.yaml` | Cron 4-5AM UTC | Scale EKS nodegroup to 0 (cost savings) |
| `non-prod-start.yaml` | Cron 12:30PM UTC | Scale EKS nodegroup to 2 |
| `cost-report-daily.yaml` | Daily | AWS cost breakdown report |
| `infra-destroy.yaml` | Manual | Terraform destroy |

## Canary Deployment Flow

The api-gateway uses Argo Rollouts. The canary strategy is defined in `kubernetes/api-gateway/deploy.yaml` and validated via `kubernetes/api-gateway/analysis-template.yaml` (Prometheus queries for error rate/latency).

```bash
kubectl argo rollouts get api-gateway -w     # monitor
kubectl argo rollouts promote api-gateway    # promote canary to stable
kubectl argo rollouts abort api-gateway      # rollback
```

## Observability

- **Metrics**: Spring Boot Actuator → Prometheus (via ServiceMonitor in `kubernetes/monitoring/petclinic-servicemonitor.yml`)
- **Dashboards**: Grafana (deployed via kube-prometheus-stack Helm chart)
- **Local**: `app/docker/prometheus/` and `app/docker/grafana/` for Docker Compose setup
- **Port-forward access**: Prometheus `:9090`, Grafana `:3000` (admin/prom-operator)

## Key Secrets Required for CI

`DOCKER_USERNAME`, `DOCKER_TOKEN`, `SONAR_TOKEN`, `SONAR_HOST_URL`, `SONAR_PROJECT_KEY`, `SONAR_ORG`, `AWS_ROLE_ARN`, `AWS_ROLE_ARN_INFRA`, `AWS_REGION`, `EKS_CLUSTER_NAME`, `EKS_NODEGROUP_NAME`, `ALERT_EMAIL`, `RDS_USERNAME`
