# STAR Story 2: Improving the CI/CD Pipeline with Canary Deployment

**Question:** "Tell me about a time you improved a CI/CD pipeline."

---

## Situation

In my Spring Boot microservices project on EKS, I had CI checks for SonarCloud and Trivy running on every PR, but those are static checks — they can't catch runtime regressions like increased 5xx error rates or latency spikes that only appear under real traffic. A bad image could still reach production and impact 100% of users instantly.

## Task

I needed a deployment strategy that would catch runtime issues *before* full rollout, with automated rollback — not just manual intervention.

## Action

I introduced Argo Rollouts for the api-gateway service, since it's the user-facing entry point. I configured a canary strategy with three traffic weights — 20%, 50%, 100% — backed by three Kubernetes services: root, stable, and canary, with the AWS ALB splitting traffic between stable and canary pods. I then wrote an AnalysisTemplate that queries Prometheus every 30 seconds for the 5xx error rate over a 5-minute window. If error rate exceeds 5%, Argo automatically aborts the rollout and ALB shifts 100% of traffic back to the stable version. Between the 50% and 100% steps, I added a manual approval pause so a human validates before full promotion. I chose canary over blue-green because blue-green doubles infrastructure cost — canary gives progressive exposure on the same node footprint, which matters for a $20/month budget portfolio.

## Result

Deployments now surface regressions at the 20% stage instead of 100%, limiting blast radius by 5x. Rollback time dropped from a manual `kubectl rollout undo` (minutes) to automated abort (under 1 minute). And because the analysis is Prometheus-driven, the gate is objective — no "LGTM" guesswork.

---

## Key Delivery Tips

- Start with the problem: "static checks can't catch runtime regressions" — interviewers nod at this
- Say "I" often: "I introduced", "I configured", "I wrote", "I chose"
- End with numbers: 5x blast radius reduction, <1 min rollback, 5% error threshold
- Always mention the trade-off (canary vs blue-green) — shows conscious engineering judgment

## Likely Follow-up Questions

1. **"Why did you pick 5% as the error threshold?"** → Based on baseline error rate in staging; anything 2-3x baseline signals regression.
2. **"What if Prometheus itself is down during the analysis?"** → AnalysisTemplate treats query failures as inconclusive; rollout pauses rather than progresses.
3. **"Why only canary for api-gateway and not all services?"** → api-gateway is the user-facing entry point with traffic that can be measured via ALB metrics. Backend services have lower blast radius and can use rolling updates.
4. **"How would you extend this to multiple services?"** → Parameterize the AnalysisTemplate, apply canary to critical services (customers-service), and keep rolling updates for non-critical ones.
