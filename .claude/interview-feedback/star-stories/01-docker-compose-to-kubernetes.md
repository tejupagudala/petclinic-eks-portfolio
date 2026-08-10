# STAR Story 1: Docker Compose Dependency Hell to Kubernetes-Native

**Question:** "Tell me about a time you faced a technical challenge that you had to figure out on your own."

---

## Situation

I was running seven Spring Boot microservices locally with Docker Compose. Every service depended on two infrastructure services -- a Config Server for configuration and a Eureka Discovery Server for service routing. If either one wasn't fully healthy before the other services started, I'd get cascading connection failures across all services.

## Task

I needed to make the services start reliably and eventually make them production-ready for Kubernetes.

## Action

First, I fixed the immediate problem -- I added health checks and `depends_on` conditions in Docker Compose so services waited for Config Server and Eureka to be healthy before starting. That worked locally, but when I moved to Kubernetes, I realized the real fix was architectural. Kubernetes already provides what Config Server and Eureka do -- ConfigMaps for configuration and DNS-based Service discovery. So I disabled both Spring Cloud services in Kubernetes, moved each service's configuration into its own ConfigMap, and replaced Eureka lookups with Kubernetes service DNS names like `customers-service.petclinic.svc.cluster.local`.

## Result

Each microservice became self-contained -- no shared infrastructure dependency at startup. Pod startup became faster and more reliable because there's no waiting on external config or discovery. And it simplified debugging -- if a service fails, the problem is in that service, not in a dependency chain three levels deep.

---

## Follow-up Answers

**"Why not keep Eureka in Kubernetes?"**
> Kubernetes Service discovery is built-in -- adding Eureka would be redundant complexity and another thing to monitor.

**"What about Config Server?"**
> ConfigMaps are Kubernetes-native, version-controlled in Git alongside manifests, and don't require a running service to serve config.

---

*Delivery: Under 2 minutes. Pause between S-T-A-R sections.*
