# Security Pipeline README

## Goal
This document captures the security improvements added to the project CI/CD pipeline, what changed in code/infrastructure, and the issues faced during setup with their fixes.

## What We Added
1. SonarQube/SonarCloud static analysis in CI for `spring-petclinic-api-gateway`.
2. Trivy security gates in CI:
   - Filesystem scan for `app/` (dependencies + secrets).
   - Kubernetes misconfiguration scan for `kubernetes/api-gateway`.
   - Terraform misconfiguration scan for `terraform`.
   - Docker image vulnerability scan after image build.
3. Security hardening for Kubernetes and Terraform so Trivy `HIGH/CRITICAL` checks pass.
4. CI trigger updates so Terraform security changes always trigger pipeline runs.

## CI Security Flow
Workflow: `.github/workflows/ci.yaml`

1. `build`:
   - Build api-gateway
   - Run unit tests
2. `code-quality`:
   - Run Sonar analysis
   - Wait for quality gate (`-Dsonar.qualitygate.wait=true`)
3. `security-scan`:
   - Trivy FS scan (`app/`)
   - Trivy config scan (`kubernetes/api-gateway`)
   - Trivy config scan (`terraform`)
4. `docker`:
   - Build/push image
   - Trivy image scan
5. `updatek8s`:
   - Update image tag in `kubernetes/api-gateway/deploy.yaml`
   - Commit and push manifest update

## Files Changed (Since Yesterday)
1. `.github/workflows/ci.yaml`
   - Added/kept Sonar analysis for api-gateway module.
   - Enforced Trivy scans with `exit-code: '1'`.
   - Added `terraform/**` to workflow trigger paths.
2. `app/pom.xml`
   - Dependency management overrides for vulnerable libraries:
     - `tools.jackson.core:jackson-core` -> `3.1.0`
     - `com.fasterxml.jackson.core:jackson-core` -> `2.21.1`
     - `org.assertj:assertj-core` -> `3.27.7`
3. `app/spring-petclinic-api-gateway/pom.xml`
   - Added JaCoCo plugin to generate XML coverage report for Sonar.
4. `app/spring-petclinic-api-gateway/src/test/resources/application-test.yml`
   - Added route URIs for tests to avoid placeholder resolution failures.
5. `app/spring-petclinic-api-gateway/src/main/java/.../FallbackController.java`
   - Switched to explicit `@GetMapping("/fallback")` and fixed import.
6. `kubernetes/visits-service/deploy.yaml`
   - Added security context for init containers and app container.
7. `kubernetes/api-gateway/deploy.yaml`
   - Added pod-level and container-level security context (`runAsNonRoot`, `readOnlyRootFilesystem`, seccomp, drop caps, no privilege escalation).
8. `terraform/backend/main.tf`
   - Added S3 public access block for backend bucket.
   - Switched S3 encryption to KMS CMK.
9. `terraform/cost_guardrails.tf`
   - Added KMS CMK for SNS topic encryption.
   - Tightened GitHub Actions IAM policy:
     - Removed `budgets:Describe*`.
     - Scoped budget resources to budget ARNs.
     - Scoped EKS resources to cluster/nodegroup ARNs.
     - Removed unneeded Cost Explorer actions; kept only `ce:GetCostAndUsage`.
10. `terraform/modules/eks/main.tf`
    - Enabled EKS secret encryption with KMS.
    - Set control plane endpoint to private-only (`endpoint_public_access=false`, `endpoint_private_access=true`).
11. `terraform/modules/vpc/main.tf`
    - Set `map_public_ip_on_launch = false` for public subnets.

## Issues Faced and How We Solved Them
1. Sonar failed: "Automatic Analysis is enabled."
   - Cause: Sonar automatic analysis + CI analysis both enabled.
   - Fix: Disabled automatic analysis in Sonar, kept CI-based analysis.

2. Sonar quality gate failed with low/zero coverage.
   - Cause: JaCoCo report missing and/or tests not producing coverage.
   - Fix: Added JaCoCo plugin and Sonar XML report path in CI.

3. Maven test failures in api-gateway.
   - Cause: missing route URL placeholders in test profile.
   - Fix: added required URLs in `application-test.yml`.

4. Compile error in `FallbackController` (`GetMapping` symbol not found).
   - Cause: missing import after annotation change.
   - Fix: added `org.springframework.web.bind.annotation.GetMapping` import.

5. Trivy FS scan failed with dependency CVEs across modules.
   - Cause: vulnerable transitive versions (`jackson-core`, `assertj-core`).
   - Fix: pinned safe versions in parent `app/pom.xml` dependencyManagement.

6. Trivy config scan failed for Kubernetes containers.
   - Cause: missing security contexts.
   - Fix: added strict security contexts in deployment manifests.

7. Trivy config scan failed for Terraform backend and infra.
   - Cause: public access block/encryption/IAM least-privilege/security defaults missing.
   - Fix: added backend bucket protections, CMK encryption, scoped IAM permissions, EKS secret encryption, private endpoint, safer subnet defaults.

8. CI still reported old Terraform IAM wildcard errors after fixes.
   - Cause: stale run context and workflow did not trigger on Terraform-only changes.
   - Fix: added `terraform/**` to CI trigger paths and re-ran using latest commit SHA.

9. Trivy local command not found.
   - Cause: Trivy not installed locally.
   - Fix: installed Trivy and validated scans locally before pushing.

## Validation Runbook
1. Local validation:
   - `trivy fs app/ --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1`
   - `trivy config kubernetes/api-gateway --severity HIGH,CRITICAL`
   - `trivy config terraform --severity HIGH,CRITICAL`
2. CI validation:
   - Push to `main` (or open PR touching configured paths).
   - Confirm jobs pass in order: `build` -> `code-quality` -> `security-scan` -> `docker` -> `updatek8s`.
3. Deployment validation:
   - Verify deployed image tag:
     - `kubectl -n petclinic get deploy api-gateway -o jsonpath='{.spec.template.spec.containers[0].image}'`
   - Verify rollout:
     - `kubectl -n petclinic rollout status deploy/api-gateway`

## Security Trade-off Notes
1. EKS control plane endpoint is private-only now.
   - Benefit: stronger control-plane security posture.
   - Impact: local `kubectl` from laptop requires VPC path (VPN/bastion/SSM).

## Required CI Secrets
1. `SONAR_TOKEN`
2. `SONAR_HOST_URL`
3. `SONAR_PROJECT_KEY`
4. `SONAR_ORG`
5. `DOCKER_USERNAME`
6. `DOCKER_TOKEN`

## Current Status
1. Sonar + Trivy are integrated in CI.
2. Trivy security gates are enforced at `HIGH/CRITICAL`.
3. Kubernetes and Terraform security findings from the setup phase have been remediated.

## Terraform Changes Included
1. Backend state bucket hardening:
   - Public access block enabled.
   - KMS CMK encryption enabled.
2. Cost guardrails hardening:
   - SNS topic uses customer-managed KMS key.
   - GitHub Actions IAM policy tightened to least privilege for Budgets/EKS actions.
   - Cost Explorer permissions reduced to only `ce:GetCostAndUsage` for current workflow needs.
3. EKS module hardening:
   - EKS secrets encryption enabled with KMS.
   - Control plane endpoint set to private-only.
4. VPC module hardening:
   - `map_public_ip_on_launch = false` on public subnets.

## Grafana / Monitoring Status
1. What exists now:
   - Local Docker observability assets exist under `app/docker/grafana` and `app/docker/prometheus`.
   - Kubernetes monitoring manifests exist under `kubernetes/monitoring/`.
   - Monitoring setup is documented in `kubernetes/monitoring/README.md`.
2. What is not yet fully automated in Terraform:
   - Helm install of `kube-prometheus-stack` (Prometheus + Grafana) is still manual/runbook-based.
   - ServiceMonitor apply is still manual/runbook-based.
3. Recommended next step for full automation:
   - Add Terraform Helm resources for `kube-prometheus-stack`.
   - Add manifest automation for `kubernetes/monitoring/petclinic-servicemonitor.yml`.
   - Add readiness checks in CI/bootstrap workflow (`kubectl -n monitoring get pods`, Prometheus/Grafana health checks).
