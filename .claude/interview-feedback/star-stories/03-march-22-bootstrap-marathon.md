# STAR Story 3: The March 22 Bootstrap Marathon

**Question variants this story answers:**
- *"Tell me about your hardest engineering day."*
- *"Tell me about a time you persevered through a difficult problem."*
- *"Walk me through a debugging story."*
- *"How do you handle pressure under tight constraints?"*
- *"Tell me about a time you had to learn fast while debugging."*
- *"Tell me about a project where you went deep on a single problem."*

**One story, six question variants.** Maximum leverage.

---

## Situation

By March 21, 2026, I had all the pieces of my Spring Petclinic EKS platform working independently. Terraform created my VPC, EKS cluster, and RDS database. My self-hosted GitHub Actions runner inside the VPC was registered and could reach my private EKS endpoint. My CI pipeline built and pushed Docker images. My Helm charts for the AWS Load Balancer Controller, Argo CD, Argo Rollouts, and kube-prometheus-stack all installed cleanly when I ran them manually.

**But I had never run all of it end-to-end from zero.** Bringing the platform up from `terraform destroy` to a fully running Petclinic took me 15+ manual steps and 30 minutes of focused attention — opening AWS console tabs, copy-pasting commands, debugging errors as they came up.

## Task

On March 22, I decided to build a single GitHub Actions workflow that does all of it with one click — `infra-bootstrap.yaml`. The goal: take the platform from `terraform destroy` to fully running Petclinic, automatically, end-to-end.

I expected this to take a few hours of dedicated work.

**I was wrong.** It took the whole day and over 20 commits.

## Action

The day broke into five chapters of failures, each exposing the next problem in the cold-start path.

**Chapter 1 — Identity (5 commits).** First, AWS didn't recognize my CI's identity at the Kubernetes layer. Even though my CI had AWS credentials via OIDC federation, when I tried to run `kubectl get pods` from the runner, EKS returned "Unauthorized." That's because EKS has its own access control on top of AWS IAM — being a valid IAM principal isn't enough; you need to be in EKS Access Entries. I added Terraform resources to attach `AmazonEKSClusterAdminPolicy` to my CI role. Then Terraform tried to create an IAM OIDC Identity Provider that already existed in my account and failed with `EntityAlreadyExistsException` — commits `aab7a3a` and `2a9d93b` fixed this with a conditional create pattern: `count = var.github_oidc_provider_arn == "" ? 1 : 0`. If a variable provides the existing ARN, Terraform reuses it; otherwise creates fresh. Finally, kubeconfig set in one workflow step was gone in the next because each step gets a fresh shell — I fixed this by saving kubeconfig to `$RUNNER_TEMP/kubeconfig` and exporting via `$GITHUB_ENV` so all subsequent steps inherit it.

**Chapter 2 — Certificates (5 commits).** Next, the AWS Load Balancer Controller's admission webhook kept breaking. The controller installs two webhooks — a mutating and a validating one — that intercept Ingress and Service creates. They're TLS-protected with a cert stored in a Kubernetes Secret called `aws-load-balancer-tls`. When my Helm install crashed mid-way — network blip, timeout, OOM — the webhook configurations stayed in the cluster (they're cluster-scoped, not namespaced), but the TLS Secret could be missing or stale. Every subsequent kubectl apply against the cluster failed with TLS verification errors, even for completely unrelated resources, because both webhooks intercepted everything. The cluster was effectively locked. Commit `c807b8f` was my fix: a preflight pattern that does `kubectl apply --dry-run=server` against a test Service manifest. If the dry-run fails because of webhook corruption, the script nukes everything — both webhook configurations, the TLS Secret, the webhook Service, and the controller Deployment, all with `--ignore-not-found` for idempotency — then reinstalls fresh via `helm upgrade --install`. I also added IRSA annotation drift detection because the ServiceAccount's `eks.amazonaws.com/role-arn` annotation sometimes didn't match what Terraform had created. And I added a "Refresh AWS credentials before readiness checks" step because the bootstrap runs longer than the 1-hour STS credential lifetime — without refresh, the last few steps would fail with expired tokens.

**Chapter 3 — Order (4 commits).** Then I hit race conditions in the Petclinic deploy. Pods started before the MySQL Secret existed, so they crashed with "secret not found." I reordered: first create the petclinic namespace, then fetch RDS credentials from AWS Secrets Manager and create a Kubernetes Secret called `mysql-credentials`, THEN apply the pod manifests. On re-runs, the petclinic namespace was sometimes stuck in `Terminating` state from a previous failed deploy that had finalizers — meaning I couldn't create a fresh namespace because the old one wouldn't fully delete. The fix was a wait loop that polls for the namespace to finish terminating; if it's still stuck after 5 minutes, force-finalize via `kubectl get namespace petclinic -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/petclinic/finalize" -f -`. This clears the finalizers and the namespace fully deletes, so the new one can be created.

**Chapter 4 — Paradox (3 commits).** Then I had to build the companion destroy workflow. I originally wrote it to run on my self-hosted runner — but the destroy workflow's job is to destroy the runner. The runner kept dying mid-workflow because Terraform was terminating the EC2 it was running on. Bootstrap paradox in reverse. The fix in commit `8dfeb7d` was to move destroy to GitHub-hosted runners — they outlive the resources being destroyed because they have nothing to do with my AWS account. I also made the cleanup steps idempotent — tolerate "instance already gone" errors so re-runs don't fail. And I added `concurrency: { group: terraform-${{ github.repository }}, cancel-in-progress: false }` to all my terraform workflows. This means if a second terraform workflow is triggered while one is running, it WAITS — doesn't cancel mid-apply, because killing terraform mid-flight would corrupt the S3 state file.

**Chapter 5 — Cleanup (2 commits).** Finally, two smaller commits — applied Pod Security Standards Restricted profile to api-gateway and updated some UI content.

## Result

By end of day on March 22, I had a 635-line bootstrap workflow that reliably runs from `terraform destroy` to fully running Petclinic in **22 minutes — one click**. It's idempotent: every step is either a declarative apply, a preflight-guarded change, or a read-only check. No unguarded one-time actions. It has matching destroy workflow, workflow concurrency to prevent state corruption, and `if: failure()` diagnostic dumps for after-hours debugging. On success, it automatically triggers `e2e-smoke.yaml` via the `workflow_run: completed` chain — three curl calls validate the full path from public ALB through Petclinic services to RDS.

**Every recovery pattern in that 635-line workflow came from a specific failure I debugged that day. Not theoretical — earned.**

The commit messages from that day — `aab7a3a` "oidc provider", `2a9d93b` "Fix bootstrap OIDC reuse", `c807b8f` "Reset stale ALB webhook cert state", `7b4a357` "Fix stuck petclinic namespace handling", `8dfeb7d` "Run infra destroy on GitHub-hosted runner" — are essentially the runbook for the workflow. They document why every recovery step exists.

## Lessons

Three takeaways from this day.

**First**, cold-start paths reveal bugs that warm-start hides. When the platform is already running, you have lots of fallback assumptions — IAM roles exist, OIDC providers exist, kubeconfig works, namespaces aren't stuck. When you destroy everything and rebuild from a truly empty AWS account, every assumption has to be created in order. Every chicken-and-egg, every race condition, every "I assumed X existed" surfaces simultaneously.

**Second**, idempotency has to be designed in from the start, not bolted on later. The preflight cascades for Helm, the dry-run detection for the ALB webhook, the force-finalize for stuck namespaces — these all came AFTER hitting the problems. Retrofitting idempotency took significantly more time than designing it in would have. The principle going forward: every step in any workflow should either make a deterministic change or be a no-op. No unguarded one-time actions.

**Third**, sequential ordering of operations matters as much as the operations themselves. It's not just what you do — it's what you do before what. Most of my March 22 fights were about ordering: the runner needs to exist before terraform can use it; the OIDC provider needs to be registered before the IAM role can trust it; the IAM role needs to be in EKS Access Entries before kubectl works; the MySQL Secret needs to exist before pods reference it. Get the order right, the workflow runs smoothly. Get it wrong, you fight cascading failures.

---

## Key Delivery Tips

- **Start with the emotional setup:** "I expected a few hours. I was wrong." Sets the tone.
- **Use the 5-chapter framework:** Identity → Certificates → Order → Paradox → Cleanup. Easy to remember under interview pressure.
- **Cite specific commit hashes:** `aab7a3a`, `c807b8f`, `8dfeb7d` — receipts that make the story unimpeachable.
- **Land the killer line:** *"Every recovery pattern came from a specific failure, not from theory."*
- **End with the 3 lessons:** cold-start brittleness, design-in idempotency, ordering matters.
- **Total length: ~2 minutes spoken** — appropriate for behavioral STAR.

## Likely Follow-up Questions

1. **"What would you do differently if you started over?"** → Build idempotency in from day one. Write the preflight checks BEFORE the first install attempt, not after the third crash.
2. **"How did you debug each failure?"** → Read workflow logs first, then `kubectl describe` on failing resources, then `kubectl events`. Helm-specific issues required `helm status` + `helm history`.
3. **"What's the most surprising bug you hit?"** → The ALB webhook locking the entire cluster. I'd never expected a single failed Helm install to block kubectl apply for unrelated resources.
4. **"Have you re-used these patterns elsewhere?"** → The preflight cascade pattern (status check → rollback → uninstall → fresh install) applies to any Helm release. The `if: failure()` diagnostic dump pattern works for any workflow. The conditional create pattern (`count = var.X == "" ? 1 : 0`) works for any AWS resource that might already exist.
5. **"What would have happened if you hadn't made it idempotent?"** → Every failed bootstrap would require manual cleanup before re-running. A 22-minute bootstrap could turn into hours of fix-the-state-and-retry cycles.

---

## How to use this story

- **Practice it out loud 3 times before any behavioral interview** — get the 5-chapter rhythm into your mouth.
- **Time yourself** — aim for ~2 minutes spoken.
- **Don't memorize verbatim** — internalize the 5 chapters as plot points, let the words flow.
- **Always cite at least 2 commit hashes** — they're the receipts that distinguish "I lived this" from "I read about this."
