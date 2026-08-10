# AIOps Assistant

This folder is the home for all AIOps assistant work in this repo.

The assistant itself is not implemented yet. What has been completed so far is the infrastructure and observability setup needed to support it.

## Contents

- [README.md](./README.md)
- [ARCHITECTURE.md](./ARCHITECTURE.md)
- [API_CONTRACT.md](./API_CONTRACT.md)
- [IMPLEMENTATION_PLAN.md](./IMPLEMENTATION_PLAN.md)

## Goal

The target design is a chat-style AIOps assistant for the Petclinic platform that can answer incident questions by using:

- `fetch_logs`
- `fetch_metrics`
- `fetch_service_health`

Planned data sources:

- CloudWatch Logs
- Prometheus
- Kubernetes / EKS health

## What Was Done So Far

### 1. Defined the AIOps direction

We aligned the project with a reference AIOps pattern:

- user asks an ops question
- assistant gathers evidence
- assistant returns:
  - probable root cause
  - evidence collected
  - impacted services
  - recommended fix
  - confidence / unknowns

### 2. Prepared the EKS observability foundation

We enabled CloudWatch observability on EKS so the future assistant can read real platform logs.

This setup used:

- the `amazon-cloudwatch-observability` EKS add-on
- the `eks-pod-identity-agent` EKS add-on
- an IAM role with `CloudWatchAgentServerPolicy`

Terraform for this was added under:

- [terraform/cloudwatch_observability.tf](../terraform/cloudwatch_observability.tf)

### 3. Installed CloudWatch observability components in the cluster

Once the add-on was installed, AWS automatically deployed:

- Fluent Bit
- CloudWatch Agent
- the CloudWatch observability controller

Their roles:

- Fluent Bit collects pod/container logs and forwards them to CloudWatch Logs
- CloudWatch Agent collects platform telemetry
- the controller manages the observability resources for the add-on

### 4. Verified the observability components were running

We verified the add-on by checking:

```bash
kubectl get pods -n amazon-cloudwatch
kubectl get daemonsets -n amazon-cloudwatch
kubectl get amazoncloudwatchagent -A
```

We confirmed:

- `amazon-cloudwatch-observability-controller-manager` was running
- `cloudwatch-agent` daemonset was running
- `fluent-bit` daemonset was running

### 5. Verified CloudWatch log groups were created

We verified the EKS observability pipeline created these log groups:

- `/aws/containerinsights/demo-eks-cluster/application`
- `/aws/containerinsights/demo-eks-cluster/dataplane`
- `/aws/containerinsights/demo-eks-cluster/host`
- `/aws/containerinsights/demo-eks-cluster/performance`

The most important one for the future assistant is:

- `/aws/containerinsights/demo-eks-cluster/application`

That is the main source for application pod logs.

### 6. Validated the log shipping path

The log pipeline we established was:

1. Petclinic pods write logs to stdout/stderr
2. Fluent Bit collects those logs from the nodes
3. Fluent Bit ships them to CloudWatch Logs
4. CloudWatch stores them under the Container Insights log groups

This is the basis for the future `fetch_logs` tool.

### 7. Stabilized the infrastructure pipeline

We also fixed several infra issues that were blocking a reliable AIOps setup:

- Terraform backend/bootstrap issues
- stale Terraform locks
- missing Terraform variables like `rds_username`
- KMS permissions for EKS secrets encryption
- GitHub OIDC provider reuse
- self-hosted GitHub runner registration issues
- wrong GitHub Actions role usage
- workflow variable parsing issues for Terraform
- cluster capacity issues during bootstrap

This work made the infra path reproducible enough to support future AIOps development.

## What This Means For the Assistant

At this point, the project had the required backend evidence sources for an AIOps assistant:

- `fetch_logs` -> CloudWatch Logs
- `fetch_metrics` -> Prometheus
- `fetch_service_health` -> Kubernetes / EKS

In plain English:

the platform had the logs, metrics, and health signals the assistant would need to investigate incidents.

## Recommended Final Architecture

The preferred direction discussed for this repo is:

- simple chat UI first
- separate `aiops-service`
- Bedrock used for reasoning
- CloudWatch / Prometheus / Kubernetes used as tool backends

This is preferred over putting all AIOps logic inside the current generic chatbot service.

## What Is Still Pending

The actual AIOps assistant implementation still needs to be built:

1. create the `aiops-service`
2. implement `fetch_logs`
3. implement `fetch_metrics`
4. implement `fetch_service_health`
5. connect the service to Bedrock for reasoning
6. add a simple UI, likely chat-based first

## Notes

- This folder is intended to hold all future AIOps assistant files.
- The AWS infrastructure used during setup was later destroyed to avoid ongoing charges.
- This README documents the setup and decisions completed before teardown.

## First Implementation Step: Create the AIOps Service Module

The first coding step is to create a separate Spring Boot module for the AIOps assistant:

- `app/spring-petclinic-aiops-service/`

This module will eventually hold:
- the AIOps API endpoint
- logs/metrics/health tool orchestration
- Bedrock reasoning integration
- AIOps-specific configuration and tests

### Why create a separate service

We are creating a separate service instead of putting this logic into the current generic chatbot because:

- AIOps is a different responsibility from general chatbot behavior
- it will need operational permissions for logs, metrics, and cluster health
- it is cleaner to isolate that logic in its own service
- it is easier to test, debug, and evolve independently

### Folder structure created

The basic Spring Boot module structure is:

- `pom.xml`
- `Dockerfile`
- `src/main/java/...`
- `src/main/resources/application.yml`
- `src/main/resources/logback-spring.xml`
- `src/test/java/...`

### Why we added a new `pom.xml`

The `pom.xml` turns the folder into a real Maven/Spring Boot module.

We did not invent it from scratch. We derived it from:

1. the parent multi-module project in `app/pom.xml`
2. the conventions used by the other Spring services in this repo
3. the immediate responsibilities of the new AIOps service

### Why these dependencies were chosen

The first version of the AIOps service only needs to:

- run as a Spring Boot application
- expose REST endpoints
- validate request payloads
- expose actuator endpoints
- support tests

So we started with only the minimum dependencies:

- `spring-boot-starter-webmvc`
  - needed to create HTTP endpoints like `POST /query`

- `spring-boot-starter-actuator`
  - needed for health/info/prometheus-style operational endpoints

- `spring-boot-starter-validation`
  - needed to validate request fields like `question` and `timeRangeMinutes`

- `spring-boot-configuration-processor`
  - useful for typed configuration properties later

- `spring-boot-starter-test`
  - needed for controller and service tests

### Why we did not add Bedrock or AWS SDK yet

We intentionally did not add Bedrock, CloudWatch, Prometheus, or Kubernetes client dependencies in the first step.

Reason:

- first we need the service module to exist and build cleanly
- then we add the application entrypoint
- then DTOs, controller, and service logic
- only after that do we add CloudWatch, Prometheus, Kubernetes, and Bedrock integrations

This keeps the build simple and makes debugging easier.

### Why we register the module in the parent `app/pom.xml`

We also add:

- `<module>spring-petclinic-aiops-service</module>`

to the parent Maven project so the new service becomes part of the repo’s multi-module build.

Without that, Maven does not know the new service exists.
