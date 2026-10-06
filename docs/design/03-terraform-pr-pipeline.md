# Terraform PR Check Pipeline — study notes

## What the mentor asked for

> "Create CI/CD pipelines that run PR checks against the Terraform plan, so you can prove the Terraform plan is green."

In plain words: when someone proposes an infrastructure change, a robot should check it *before* a human merges it. Green means safe to review. Red means don't merge.

## What we built

A GitHub Actions workflow called `terraform-pr`. It runs automatically on every pull request that changes anything under `terraform/`.

It has two jobs that run one after the other.

**Job 1 — `static`.** Fast, about 20 seconds, needs no AWS access.

- `terraform fmt -check` — is the code formatted?
- `terraform validate` — is the syntax right, do all the references exist?
- `tflint` — are there mistakes the compiler doesn't catch, like unused variables or missing version pins?

If any of these fail, we stop. No point spending time on a plan when the code doesn't even parse.

**Job 2 — `plan`.** About 20 seconds. This one talks to AWS.

- Logs into AWS using a special read-only role (more on this below)
- Reads the state file from S3
- Runs `terraform plan` — compares the code to what really exists in AWS
- Posts the result as a comment on the PR: "N to add, N to change, N to destroy"

The comment updates itself every time you push. A reviewer sees exactly what would happen without reading a single log.

**What happens after merge: nothing.** Apply is still manual, through the existing `infra-bootstrap` workflow. The PR *proves* the change. It never *makes* the change.

## The important idea: the PR job can't apply, and it's not because we asked nicely

There are two ways to stop a PR from applying.

The weak way: write the workflow so it only runs `plan`. But the workflow file lives in the repo. Anyone opening a PR can edit it and add `terraform apply`. You're trusting the YAML.

The strong way — what we did: give the PR job an IAM role that **has no write permissions at all**. Now even if someone edits the workflow to run `apply`, AWS refuses every create, update and delete call. You're trusting IAM, and a PR can't change IAM.

So we made a second role, just for PRs. It's in `terraform/github_plan_role.tf`. Three parts:

**1. Who can use it — the trust policy.**
It only accepts login tokens from GitHub that say "I come from this repo, and I was issued for a pull request." A push to `main` gets a different token and is refused. This is the badge-check at the door.

**2. What it can do — the permissions.**
- `ReadOnlyAccess` (an AWS-managed policy): every "describe" and "get" call for every service. Plan needs this to ask AWS "what exists right now?"
- A small inline policy: read the state file from S3, and decrypt it (the bucket is encrypted with a KMS key).
- Nothing else. No write anywhere. No `PutObject` on the state bucket. It cannot even update the lock file.

**3. How it logs in — OIDC.**
No AWS access keys are stored in GitHub. GitHub mints a short-lived token for each run, sends it to AWS, and AWS checks it against the trust policy. The token dies in an hour.

Say it like this: *"Two roles, two identities. The pull-request token can only become the read-only role. The main-branch token can only become the apply role. Enforced by AWS, not by our YAML."*

## Two small flags worth explaining

`-lock=false` on the plan. Normally Terraform takes a lock on the state so two people don't apply at once. A plan only reads, so it doesn't need the lock — and if it took one, a PR could block a real apply. Also, taking the lock is a write, and our role can't write. So `-lock=false` is what lets the role be truly read-only.

`terraform_wrapper: false` on the setup step. The setup action normally puts a small script in front of the real Terraform to capture its output. That script can hide the real exit code and corrupt the plan file. We turn it off so a failed plan actually turns the job red.

## What the first run showed

Both jobs green. 37 seconds total.

The plan said: **67 to add, 0 to change, 0 to destroy.**

That surprised me at first — I expected "no changes." Then I checked: the environment is currently destroyed to save money. So the plan is showing exactly what a bootstrap would create. And it noticed the three IAM resources that *do* exist (the plan role we just made) and didn't try to recreate them. That's the pipeline doing its job correctly — reading real state and diffing honestly.

One thing we caught before the first run: the state bucket is encrypted with a KMS key, and `ReadOnlyAccess` doesn't include `kms:Decrypt`. We added that one permission. If we hadn't, the first run would have failed with "access denied" on reading the state.

## What we didn't do, and why

**We didn't use Atlantis or Terraform Cloud.** They're good tools for many teams and many repos. We have one repo and one environment. GitHub Actions is already here.

**We didn't auto-apply on merge.** With one environment and no staging, a bad merge would apply straight to the only thing we have. A human presses the button.

**We didn't build an ephemeral test environment per PR.** That doubles the cost to test a diff. Plan against real state is the right depth here.

**We didn't add `terraform test` yet.** That's the next layer — unit-testing the modules with mock providers, no AWS account needed. Worth adding once the modules are used by more than one root.

## Still to do

- Turn on branch protection so a red `plan` actually blocks the merge button.
- Split the Java CI so a Terraform-only PR doesn't build the app.

## If you only remember four sentences

1. Every PR touching Terraform gets fmt, validate, lint, then a real plan posted as a comment. First run green in 37 seconds.
2. The plan job uses a separate read-only IAM role that only accepts pull-request tokens. It cannot write. Enforced in IAM, not YAML.
3. `-lock=false` is what makes read-only possible — plan never touches the lock file.
4. Apply stays manual. The PR proves the change; it never makes it.
