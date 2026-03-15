# Petclinic Modernization with Docker Compose
## From Spring Cloud Config Server + Eureka to Docker DNS + Localized Config

This project modernizes the Petclinic microservices setup for a more container-native architecture in Docker Compose.

Instead of relying on:
- Spring Cloud Config Server for centralized runtime configuration
- Eureka Discovery Server for service discovery

this version uses:
- Docker Compose service-name DNS for inter-service communication
- local application configuration inside each service
- environment variables from `.env`
- API Gateway with explicit route definitions
- Prometheus and Grafana for observability

---

## Why this modernization was needed

The original Petclinic microservices architecture follows an older Spring Cloud pattern:

- `config-server` provides centralized configuration
- `discovery-server` (Eureka) provides service registration and discovery
- each service depends on those infrastructure components to boot and communicate

That architecture is useful for learning classic microservices patterns, but for a modern containerized environment it adds unnecessary moving parts.

Docker Compose already provides:
- service-to-service networking
- internal DNS resolution by service name

So instead of this:

- services ask Eureka where `customers-service` is
- services ask Config Server for config on startup

we can do this:

- gateway calls `http://customers-service:8081`
- services read config from environment variables
- Docker Compose resolves service names automatically

This makes the stack:
- simpler
- easier to debug
- closer to how Kubernetes-native systems work

---

## New architecture

### Old architecture

```text
Browser
   |
   v
API Gateway
   |
   +--> Config Server
   |
   +--> Discovery Server (Eureka)
   |
   +--> Customers Service
   +--> Vets Service
   +--> Visits Service
   +--> GenAI Service
   |
   +--> MySQL

   New architecture

   Browser
   |
   v
API Gateway (Spring Cloud Gateway)
   |
   +--> customers-service:8081
   +--> vets-service:8083
   +--> visits-service:8082
   +--> genai-service:8084
   |
   +--> mysql:3306

Docker Compose DNS handles service discovery
.env handles local runtime configuration

                     ┌─────────────────────┐
                     │     Browser / API    │
                     └──────────┬──────────┘
                                │
                                ▼
                     ┌─────────────────────┐
                     │     API Gateway     │
                     │ Spring Cloud Gateway│
                     │        :8080        │
                     └──────────┬──────────┘
                                │
        ┌───────────────┬───────────────┬───────────────┐
        ▼               ▼               ▼               ▼

┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ Customers    │ │ Vets Service │ │ Visits       │ │ GenAI        │
│ Service      │ │              │ │ Service      │ │ Service      │
│ :8081        │ │ :8083        │ │ :8082        │ │              │
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
       │                 │                │                │
       └─────────────────┴────────────────┴────────────────┘
                             │
                             ▼
                     ┌─────────────────┐
                     │      MySQL      │
                     │      :3306      │
                     └─────────────────┘


        ┌───────────────────────────────┐
        │       Observability Stack     │
        │                               │
        │ Prometheus :9091              │
        │ Grafana    :3030              │
        └───────────────────────────────┘