# My Project Story — Rehearsal Script (Plain English, but real tech)

> Read this out loud. It's written the way I'd actually talk — but I name the real tools and terms,
> then explain each one in a simple sentence. That combo is what makes me sound like I actually built
> it: I know the proper word *and* I can explain it like a normal person.
>
> It's a personal project I built to learn this stuff. I never pretend it ran at a real company. The
> numbers are real settings from my project, not made-up traffic stats.
>
> Trick for every term: **say the real name, then "...which basically means..."** Do that and you
> sound senior, not rehearsed.

---

## 1. What it is

"So at the centre there's a small app — a vet clinic system, a handful of microservices like
customers, vets, visits, and an API gateway in front of them. But the app is honestly the least
interesting part, and I kept it simple on purpose. What I actually built is the **entire platform you'd
wrap around an app to run it like a real company would** — and I built all of it myself, end to end.

So that means: all the AWS infrastructure is written as code with **Terraform** — the network, the EKS
Kubernetes cluster, the RDS MySQL database, the IAM roles, KMS encryption, the cost controls — nothing
is clicked together by hand. The whole platform is **fully reproducible from code** — I can stand it up
from an empty AWS account, or tear it down and rebuild an identical copy, with a single workflow. On top
of that there's a full **CI/CD pipeline** in GitHub Actions that builds, tests, security-scans, and
ships the code. Releases go out as **canary deployments with Argo Rollouts** that check themselves
against live metrics before going fully live. There's a complete **monitoring stack** — Prometheus,
Grafana, and AWS CloudWatch — watching the whole thing. And the newest layer is an **AIOps assistant**
that uses AWS Bedrock to help diagnose problems automatically. So it touches a lot of AWS — EKS, VPC,
RDS, IAM and IRSA, KMS, Secrets Manager, CloudWatch, load balancers, and Bedrock.

The question I set out to answer was bigger than just 'how do I deploy.' It was really: *can I build the
full thing a real platform or DevOps team owns — the infrastructure, the delivery pipeline, the
security, the monitoring, even AI-assisted operations — entirely as code, by myself, and have it
actually work?*

The part I'm proudest of is that it's **reproducible and I own every layer of it**. Because the only way
the environment can exist is by running the code, there's no configuration drift and no undocumented
setup hiding in someone's head — and that same property gives me a real disaster-recovery story. I also
treated **cost as a genuine engineering constraint** throughout, the way a cost-conscious team does — so
I can walk you through every trade-off I made between cost and availability, and tell you its production
version. So the honest pitch is: it's a small app, but a real, complete, production-shaped platform
around it, built as code, and I understand every decision in it."

---

## 2. How it's put together

> Best way to sell this: don't list the parts — **walk a single code change from my laptop to
> production** and name every layer it passes through. That proves I understand the whole system, not
> just pieces of it. Here's that walk-through.

**The foundation — it all starts as code.**
"Before any app runs, there's the infrastructure, and all of it is **Terraform** — infrastructure as
code. So instead of clicking around the AWS console, the whole environment is written down: a **VPC**
with public and private subnets across three availability zones, an **EKS cluster** — that's AWS's
managed Kubernetes — running on EC2 worker nodes, an **RDS MySQL** database, all the **IAM** roles and
permissions, **KMS** keys for encryption, and the cost guardrails. It's modular and it lives in Git, so
the entire platform is **reproducible from code** — I can stand it up from an empty AWS account, or
rebuild an identical copy, with a single workflow, my `infra-bootstrap` workflow. That reproducibility
is the thing I'm proudest of on the infra side: because the only way the environment can exist is by
running the code, there's no configuration drift and no magic, undocumented setup hiding anywhere — and
the same workflow doubles as my disaster-recovery plan.

> **Follow-up — if they ask about the `infra-bootstrap` workflow:**
>
> *Start with why it had to exist, then walk the steps.*
>
> "I built it for **reproducibility**. I wanted the entire platform to be reconstructable from code
> with no hand-clicking, so that rebuilding it gives you an identical environment every time — that's
> what kills configuration drift and gives me a disaster-recovery story. And Terraform on its own
> doesn't get me all the way there, because Terraform only builds the AWS infrastructure — the cluster,
> the network, the database. A *working* platform needs more on top of that: the controllers that have
> to run inside the cluster — the **AWS Load Balancer Controller** so the app can get a load balancer,
> **Argo Rollouts** so I can do canary deploys, **Prometheus and Grafana** for monitoring, and **Argo
> CD** for GitOps — plus the **database password** loaded in from Secrets Manager as a Kubernetes
> secret, and then the **microservices themselves** deployed. Doing all of that by hand after every
> rebuild would be slow and easy to get wrong. So I built one workflow to orchestrate the entire thing
> end to end, in the right order.
>
> Here's what it does, step by step:
> 1. It builds the **network and a self-hosted GitHub Actions runner** inside it first — I need that
>    runner because my cluster's API is private, so something inside the network has to do the rest of
>    the setup.
> 2. Then it runs **Terraform** to stand up the **cluster, the database, and all the IAM and encryption**.
> 3. Then it **installs those in-cluster controllers** — the load balancer controller, Argo Rollouts,
>    Prometheus and Grafana, and Argo CD.
> 4. Then it waits for the database, pulls its **password from AWS Secrets Manager**, and gives it to
>    the apps as a Kubernetes secret.
> 5. Finally **Argo CD deploys the microservices** from Git, and the workflow waits until everything's
>    healthy and the load balancer is live.
>
> And there's a matching destroy workflow that tears it all down and double-checks nothing got left
> behind. Because it's a personal lab, I also use that to tear it down when it's idle so I'm not paying
> for it — but in production you'd never do that; prod stays up, and you'd only ever spin *ephemeral*
> environments up and down. The teardown was never the point — it's just the cheapest way to prove the
> rebuild actually works, every single time. The honest part is that getting the *order* right was the
> hard bit — my first run from scratch failed in a bunch of places because things tried to run before
> what they depended on existed, and fixing all of that is what turned it into a real one-click
> bootstrap."

**Now let me follow a code change through it.**
Say I fix a bug and push it. First it hits my **CI pipeline in GitHub Actions**. That builds the
service, runs the tests, checks the code quality with **SonarCloud**, and then — and this is the part
I care about — it security-scans everything with **Trivy** *before* anything gets published: it scans
the code, the container image, and even the Kubernetes and Terraform files for misconfigurations. Only
if all of that passes does it build the Docker image and push it. And the whole pipeline talks to AWS
using **OIDC** — short-lived tokens instead of stored passwords — so there are no long-lived AWS keys
sitting in GitHub.

**Then the deploy — and I deliberately don't let CI touch the cluster.**
Instead of the pipeline running commands against the cluster directly, it just updates the new image
version in a Git file, and a tool running *inside* the cluster notices that and pulls the change in.
That's the GitOps idea — Git is the source of truth, and the cluster keeps itself in sync with it. The
nice payoff is that undoing a release is just reverting a commit.

**The release itself is a canary, not a big-bang switch.**
The API gateway doesn't just get replaced. Using **Argo Rollouts**, the new version comes up alongside
the old one and only **20% of traffic** goes to it first, routed by an **AWS load balancer**. Then it
pauses and actually checks itself — it queries the monitoring and asks 'are requests still succeeding,
are errors low?' If yes, it promotes to 100%; if no, it rolls itself back automatically, in seconds,
because rolling back is just shifting traffic.

**Watching all of it the whole time — observability.**
Underneath, there's a full monitoring stack I set up: **Prometheus** scrapes metrics out of every
service through Spring Boot's actuator, **Grafana** turns those into dashboards, and **AWS CloudWatch**
collects the container logs through Fluent Bit. This isn't decoration — it's the exact same monitoring
the canary uses to decide whether a release is safe. So observability is wired into the deploy, not
bolted on after.

**And threaded through everything — security and cost.**
On security: pods run locked down — non-root, read-only filesystem — secrets and the database are
encrypted with **KMS**, the cluster's API isn't wide open to the internet, and pods get their AWS
permissions through **IRSA**, which gives each one a scoped role instead of shared credentials. On
cost: there's an **AWS Budget** with alerts at 50, 80 and 100%, a daily cost report that emails me the
breakdown, anomaly detection, and the cluster literally scales its nodes down to zero overnight so I'm
not paying while I sleep.

So that's the whole shape of it — from a `git push` on my laptop, through build, scan, GitOps, a
self-checking canary, into a monitored, encrypted, cost-capped cluster — and I built and wired up every
one of those layers myself."

---

## 3. The decisions I made

"Now the interesting part — the choices. Almost every time there was an expensive 'proper' way, and I
had to find a cheaper way that was still genuinely good.

The big one is **how I deploy a new version — I use a canary deploy with Argo Rollouts.** Argo
Rollouts is a tool that replaces the normal Kubernetes deployment and gives you more control. The
simpler alternative is blue-green, where you run two full copies of everything and flip traffic over
— but two full copies cost double, and my budget couldn't take that. So with a canary, the new version
runs *next to* the old one, and I send just twenty percent of traffic to it first. If it's healthy, I
send more. If it's bad, I pull it back.

And here's the bit I'm proud of — I don't eyeball it, it checks itself. The rollout pauses and runs an
**analysis against Prometheus.** In plain terms, it queries my monitoring and asks two questions: are
at least ninety-five percent of requests succeeding, and are server errors — the 5xx errors — under
one percent? If it fails either, the rollout aborts and rolls back on its own, instantly, because
rolling back is just shifting traffic, not redeploying. If it passes, it waits for me to approve, then
goes to a hundred percent. So my monitoring isn't decoration — it's the gate that decides if the new
version is safe.

Second decision: **I run it GitOps-style.** That means my deploy pipeline never touches the cluster
directly with kubectl. The reason is security — if my pipeline held the cluster's credentials and
someone broke into it, they'd own the whole cluster. So instead, the pipeline just updates the image
tag in a Git file, and a tool inside the cluster reads Git and updates itself to match. The phrase I
use is 'CI updates Git, and the cluster deploys from Git.' Bonus: undoing a deploy is just a `git
revert`.

A small one that shows I've thought about it: **I tag every image with the CI run ID, never `latest`.**
The same Git commit can get built more than once, so the run ID is what uniquely links a running
container back to the exact build that made it. And `latest` quietly breaks rollbacks, because
Kubernetes can't tell one `latest` from another.

Then the money choices, which I'm honest about being trade-offs. **I run Spot instances** — spare AWS
capacity, about seventy percent cheaper — but the catch is AWS can reclaim them with two minutes'
notice. **I use a single NAT gateway** instead of one per availability zone, which saves about sixty
dollars a month, but if that one zone has an outage my private servers lose outbound internet. **My
RDS database is single-AZ** — one copy, no standby — which is half the price but has no automatic
failover. None of that is how you'd run it for real customers. But I knew that going in, I made each
cut on purpose, and I can tell you exactly what I'd swap for production."

---

## 4. What went wrong (the real technical war stories)

"The most honest part is what broke — you only learn this by hitting it. My first full build from an
empty AWS account was a marathon where every wrong assumption surfaced at once. A few real ones:

**The IAM OIDC provider crash.** OIDC is how GitHub Actions logs into AWS without storing a password —
AWS trusts a token GitHub hands it. But that trust setup, the 'OIDC provider,' is a one-per-account
thing — you can only create it once. My Terraform tried to create it again on a re-run and crashed
with an 'EntityAlreadyExists' error. The fix was to make Terraform check first — only create it if it
doesn't already exist, using a `count` that's zero when it's already there. The real lesson: some AWS
resources are account-wide singletons, and your code has to survive being run twice.

**The admission webhook that broke everything.** I use the AWS Load Balancer Controller to create load
balancers from Kubernetes. It installs an 'admission webhook' — basically a checkpoint that inspects
every change before Kubernetes accepts it. Its security certificate didn't match what Kubernetes
expected, so the checkpoint rejected *everything* — every single `kubectl apply` started failing, not
just load balancer stuff, because that checkpoint sits in front of the whole API. The fix was to
detect the bad certificate and reinstall the webhook cleanly. Lesson: an admission webhook is a single
point of failure for the entire cluster.

**IAM said yes, the cluster said no.** I gave my CI pipeline an IAM role to reach the cluster, and it
still got 'access denied.' Took me a while to realize AWS permissions (IAM) and Kubernetes permissions
are two totally separate systems. Being allowed by AWS doesn't mean you're allowed *inside* the
cluster. I had to add an 'EKS Access Entry' to grant the role actual Kubernetes permissions. Two
separate doors, two separate keys.

**The canary check failing on empty data.** My automated canary analysis kept failing for no reason.
Turned out it was running before Prometheus had scraped any metrics yet — so the query was dividing by
zero on an empty result and scoring it as a failure. Two fixes: I added a two-minute pause before the
analysis so there's actually data to measure, and I added a guard in the query — `clamp_min` — so the
math doesn't blow up when traffic is near zero. That's a bug you'd never catch without watching a real
deploy fail.

By the end, all of it was solved, and the whole environment could be rebuilt cleanly from nothing.
Every one of those failures basically became a guardrail that's now baked into the bootstrap."

---

## 5. What I'd do differently for real

> This is a long list on purpose — so I'm never caught short. In a real interview I'd **pick two or
> three from each theme**, not recite all of it. The skill is showing I know exactly where the
> portfolio shortcuts are and what the grown-up version looks like. I'd open with this line:
>
> "Almost every gap is the same trade — I optimised for cost, and production optimises for not going
> down. So if I had real customers and a real budget, here's what I'd change, grouped by area."

**Availability — no more single points of failure.**
"Right now a lot of things are 'just one of them.' One NAT gateway, so if that zone has a problem my
private servers lose internet — I'd run one per zone. The database is single-AZ, one copy, so I'd make
it Multi-AZ so there's a standby that takes over automatically. My nodes are all Spot, which AWS can
take back in two minutes — I'd add a baseline of normal on-demand nodes so a Spot reclaim can't evict
everything at once, and run an interruption handler so pods drain gracefully instead of just dying.
And a couple of my core services — the config server and the service-discovery server — run as a
single replica, which is bad because everything else depends on them. I'd run three of each, spread
across different nodes with anti-affinity, so losing one node doesn't take them out."

**Data and disaster recovery — assume things get deleted.**
"My database keeps only one day of backups and has deletion protection turned off, with no final
snapshot — which means one wrong `terraform destroy` and the data's just gone. For production I'd turn
on deletion protection, take a final snapshot, and keep weeks of backups with point-in-time recovery.
I'd also add a read replica so reads can scale and I have something to promote if the primary dies. And
honestly, the most embarrassing one — I've got a MySQL pod running *inside* the cluster with temporary
storage *and* a proper RDS database from Terraform. The in-cluster one loses all its data on restart. I
caught that during this audit; the fix is to delete it and have every service point at RDS only."

**Security — lock it down properly.**
"A few real gaps here. My database password is sitting in a plain Kubernetes secret file, basically in
clear text — I'd move secrets into AWS Secrets Manager and pull them in with the External Secrets
Operator so they rotate and aren't in Git. I hardened the API gateway — non-root user, read-only
filesystem, dropped Linux capabilities — because it's the most exposed, but the other services don't
have that yet, so I'd apply the same hardening everywhere and enforce it cluster-wide with Pod Security
Standards so nobody can accidentally deploy a privileged pod. There are no network policies at all
right now, meaning any pod can talk to any other pod — I'd add default-deny policies so, for example,
only the app services can reach the database. And my container images run as root because the
Dockerfile never creates a user — I'd add a proper non-root user in the image itself."

**Networking and access — shrink the blast radius.**
"My database security group currently allows the whole VPC to reach it on the MySQL port — I'd narrow
that to just the cluster's security group so a random compromised box can't connect. My CI pipeline's
permissions are broad — it effectively has cluster-admin — so I'd scope it down to only what it needs.
The build runner has a public IP; I'd move it into a private subnet. And I'd turn on the audit trails I
don't have yet — EKS control-plane audit logs, RDS logs, and VPC flow logs — so if something does go
wrong, I can actually investigate it."

**Scaling and graceful operations.**
"Everything runs a fixed number of pods right now — there's no autoscaling, so a traffic spike just
overwhelms a pod until it falls over. I'd add Horizontal Pod Autoscalers that add pods when CPU or
memory climbs. I'd add Pod Disruption Budgets so cluster maintenance can't take all my pods down at
once. My health checks are also weak — they just check that the port is open, not that the app is
actually healthy, so a pod with a dead database connection still gets traffic. I'd switch those to real
HTTP health checks against Spring Boot's actuator endpoint. And I'd add graceful shutdown — a short
drain before the pod stops — and set the Java heap size to match the container's memory limit, because
right now under load the JVM can blow past the limit and get OOM-killed silently."

**Release safety — staging, gates, and supply chain.**
"Today my code goes basically straight to the one cluster — there's no staging environment to catch
problems first. I'd add a staging cluster and bake there before promoting to prod. My deploy updates
the image tag with a `sed` command, which is fragile; I'd use a proper tool like Argo CD Image Updater
or Kustomize. There's no branch protection, so someone could push straight to main and skip CI — I'd
require pull-request reviews and passing checks. The canary auto-promotes after a quick smoke test; I'd
add a human approval gate and a metrics-based auto-rollback that watches for a couple of hours, not just
the first few minutes, since some bugs like memory leaks only show up later. And on supply chain, I'd
sign my images with cosign and generate an SBOM, then make the cluster refuse any image that isn't
signed — so a tampered image can't sneak in."

**Observability and on-call — know before the customer does.**
"I've got dashboards but no actual alerting — nothing pages me if the site goes down, I'd have to be
looking at the screen. So I'd add alerting rules and route them to PagerDuty or Slack. I'd define real
SLOs — like 99.9% availability and 95th-percentile latency under half a second — and alert on burning
through that error budget, instead of on raw numbers. I'd add distributed tracing so when a request is
slow I can see exactly which service caused it, instead of guessing across separate logs. I'd write
runbooks so whoever's on call at 3am isn't starting from zero. I'd set log retention so CloudWatch
costs don't quietly explode. And a quick one — my Argo CD is running in insecure mode with a default
password, so I'd put it behind TLS and proper login."

---

## 6. Wrapping up

"So that's the project. A simple app, but wrapped in the setup a real team would use — gradual canary
deploys that check themselves against monitoring, full observability, security baked in, all running
for under twenty bucks a month. And I can walk through every shortcut I took and exactly what I'd swap
for production.

What I'm building on top now is a little AIOps assistant — when something breaks, instead of me digging
through logs and metrics in five places, it pulls together the Kubernetes events, the CloudWatch logs,
and the Prometheus metrics, and gives me a first guess at the root cause with the evidence behind it.
Still in progress, but that's the direction."

---

## If I blank — facts + the term to use

- App: a few **microservices** on **EKS** (managed Kubernetes on AWS).
- Built with **Terraform** (infrastructure-as-code) — rebuildable from scratch.
- Deploys: **canary with Argo Rollouts** — 20% traffic first, auto-checked against **Prometheus**,
  auto-rollback if bad.
- **GitOps** — CI updates Git, the cluster deploys from Git.
- Cheap: **Spot instances**, **single NAT gateway**, **single-AZ RDS**, scales to zero overnight.
- The four war stories: **IAM OIDC provider** (only one per account), **admission webhook** cert broke
  every apply, **IAM vs EKS Access Entry** (two separate permission systems), **canary analysis**
  divided by zero on empty Prometheus data.

---

### How to practice
1. Read it all out loud once, slow — about 4–5 minutes if you read everything.
2. Drill the **"say the term, then explain it"** rhythm. Cover the explanation, just read the term,
   and explain it in your own words. That's the skill an interviewer is testing.
3. In the real interview: give sections 1 and 2, then stop and let them pull the rest with questions
   ("how do the deploys work?", "what broke?"). Drop into that section when they ask.
4. Final pass: tell it with the file closed, using only the six headings as your map.
