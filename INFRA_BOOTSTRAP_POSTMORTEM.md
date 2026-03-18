# Infra Bootstrap Postmortem (2026-03-17 to 2026-03-18)

This document summarizes the issues encountered while running `infra-bootstrap`, the root causes, and the fixes that made the workflow stable. It is written for quick scanning and future troubleshooting.

## Summary

We hit a chain of failures across tooling, cluster access, Helm release state, ALB controller setup, webhook TLS, and node capacity. The fixes were a mix of workflow hardening, Terraform adjustments, and operational cleanup.

## Root Causes and Fixes

| Issue | Root Cause | Fix |
| --- | --- | --- |
| `kubectl: command not found` | Runner lacked `kubectl` | Install `kubectl` explicitly in workflows and verify `kubectl version --client`. |
| Exec auth errors in kubeconfig | Manual `kubectl config set-credentials` override missing required exec fields | Removed manual override; rely on `aws eks update-kubeconfig`. |
| Unauthorized to cluster | Workflow role not mapped to cluster access | Use EKS access entries and associate cluster admin policy. |
| Helm release `pending-*` | Prior interrupted Helm operations left locks | Added pending-release rollback/uninstall logic before installs. |
| ALB controller deployment had 0 pods | ServiceAccount missing; IRSA role missing | Set `serviceAccount.create=true` and reinstalled; attached controller policy to node role for stability. |
| Webhook TLS failures | Webhook CA/secret out of sync | Reinstall controller to regenerate certs and webhook resources. |
| Prometheus/Argo pods Pending | Node pod capacity exhausted | Temporarily scaled node group to 2–3 nodes. |
| OIDC assume role failures during destroy | OIDC provider destroyed mid-run | Finish destroy locally using AWS credentials, or re-create OIDC provider first. |
| `iam_policy.json` file path error | Wrong file path in module | Use `file("${path.root}/../iam_policy.json")`. |

## Workflow Hardening Added

These changes were implemented to reduce future failures.

1. Concurrency guard to prevent overlapping `infra-bootstrap` runs.
2. Pending Helm release cleanup for ALB controller.
3. Failure diagnostics for ALB controller: pods, describe, logs, events.
4. Webhook CA preflight before Prometheus install; reinstalls controller if invalid.
5. Cluster-only destroy workflow that keeps VPC and runner.
6. Post-destroy verification step to detect leftover resources, including EBS volumes and snapshots.

## Operational Notes

1. ALB controller depends on a ServiceAccount. If the deployment shows 0 pods with `serviceaccount not found`, reinstall with `serviceAccount.create=true`.
2. `t3.small` nodes hit pod limits quickly. If installs stall with `Too many pods`, scale the node group.
3. Webhook TLS errors (`x509`) are fixed by reinstating the ALB controller so it regenerates the webhook certs.
4. Helm `pending-*` means a previous install or upgrade left a lock. Roll back or uninstall before retrying.

## Destroy Behavior

There are now two paths.

1. Full destroy (`infra-destroy`): deletes cluster, VPC, and runner. Next apply requires re-creating and re-registering the runner.
2. Cluster-only destroy (`infra-destroy-cluster`): deletes only `module.eks`, keeps VPC and runner intact.

## Cost Cleanup Verification

The destroy workflow now checks for leftover cost-bearing resources.

1. EKS cluster still present.
2. Runner EC2 instance still present.
3. Project VPC still present.
4. NAT gateways still present.
5. ALB/NLB still present in the VPC.
6. Tagged Elastic IPs still present.
7. Detached EBS volumes tagged with the cluster name.
8. EBS snapshots tagged with the cluster name.

If any of these remain, the destroy workflow fails with a clear message.