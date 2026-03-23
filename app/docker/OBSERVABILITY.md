# Local Observability Runbook (Docker Compose)

This guide documents how to run observability locally for the app stack using Docker Compose.

Scope:

- Application metrics from Spring Boot Actuator
- Prometheus scraping local service metrics
- Grafana visualization

## 1) What this setup uses

Files used in this repo:

- `app/docker-compose.yml`
- `app/docker/prometheus/prometheus.yml`
- `app/docker/prometheus/Dockerfile`
- `app/docker/grafana/Dockerfile`
- `app/docker/grafana/provisioning.yml`

Published ports from compose:

- API gateway: `8080`
- Customers: `8081`
- Visits: `8082`
- Vets: `8083`
- Prometheus: `9091` (container `9090`)
- Grafana: `3030` (container `3000`)

## 2) Start clean to avoid container-name conflicts

```bash
cd app
docker compose down --remove-orphans

# optional if old standalone containers exist with same names
docker rm -f config-server discovery-server customers-service visits-service vets-service api-gateway mysql prometheus-server grafana-server 2>/dev/null || true
```

Why:

- This compose file uses fixed `container_name` values.

If skipped:

- `docker compose up` fails with `container name ... is already in use`.

## 3) Start the stack

```bash
docker compose up -d --build
docker compose ps
```

Expect these services `Up`:

- `mysql`
- `config-server`
- `discovery-server`
- `customers-service`
- `visits-service`
- `vets-service`
- `api-gateway`
- `prometheus-server`
- `grafana-server`

Why:

- Prometheus and Grafana depend on app services being reachable.

If skipped:

- Metrics endpoints fail; Prometheus targets stay down.

## 4) If services crash at startup, check config-server timing first

Common failure:

- `ConfigClientFailFastException`
- `Connection refused` or `UnknownHostException` for `config-server`

Checks:

```bash
docker compose logs config-server --tail=100
docker compose logs customers-service --tail=100
docker compose logs visits-service --tail=100
docker compose logs vets-service --tail=100
```

Fix:

- Ensure `config-server` is `Up` before dependent services.
- Restart all app services after config-server is healthy:

```bash
docker compose restart customers-service visits-service vets-service api-gateway
```

Why:

- Services pull config from config-server during bootstrap.

If skipped:

- App ports `8080-8083` will not open, so no app metrics.

## 5) Validate Actuator Prometheus endpoints

```bash
curl -i http://localhost:8080/actuator/prometheus
curl -i http://localhost:8081/actuator/prometheus
curl -i http://localhost:8082/actuator/prometheus
curl -i http://localhost:8083/actuator/prometheus
```

Expect:

- `HTTP/1.1 200` and Prometheus text output.

Why:

- Confirms app metrics are exposed before scraping.

If skipped:

- You may debug Prometheus unnecessarily when issue is app endpoint exposure.

## 6) Validate Prometheus is scraping targets

Open:

- `http://localhost:9091/targets`

Or query in Prometheus UI:

```promql
up
up{job=~"api-gateway|customers-service|visits-service|vets-service"}
```

Expect:

- value `1` for each job.

Why:

- Confirms scrape connectivity and target health.

If skipped:

- Grafana panels can stay empty even when services are running.

## 7) Generate traffic so app charts move

```bash
for i in {1..30}; do curl -s http://localhost:8080/api/customer/owners >/dev/null; done
for i in {1..30}; do curl -s http://localhost:8080/api/vet/vets >/dev/null; done
for i in {1..30}; do curl -s http://localhost:8080/api/visit/owners/1/pets/1/visits >/dev/null; done
```

Why:

- Request-rate metrics stay near zero on idle systems.

If skipped:

- You might assume observability is broken while traffic is simply absent.

## 8) Application metrics queries to run in Prometheus

```promql
sum(rate(http_server_requests_seconds_count{job=~"api-gateway|customers-service|visits-service|vets-service"}[5m])) by (job,status)
```

```promql
sum(rate(http_server_requests_seconds_sum{job=~"api-gateway|customers-service|visits-service|vets-service"}[5m])) by (job)
/
sum(rate(http_server_requests_seconds_count{job=~"api-gateway|customers-service|visits-service|vets-service"}[5m])) by (job)
```

```promql
sum(jvm_memory_used_bytes{job=~"api-gateway|customers-service|visits-service|vets-service",area="heap"}) by (job)
```

Note on `405`:

- You may see `status="405"` in request metrics for some probes/methods.
- This is method/path behavior, not a scrape failure by itself.

## 9) Grafana setup

Open:

- `http://localhost:3030`

Data source URL when asked:

- `http://prometheus-server:9090` (inside compose network)

Why:

- Grafana container reaches Prometheus by service name, not `localhost`.

If skipped:

- Data source tests fail from Grafana.

## 10) Dashboard organization (local)

Create three dashboard groups/folders:

- `Application`
- `Kubernetes` (for k8s environment; optional in local docker)
- `Infrastructure`

For local docker, focus on `Application` panels from section 8.

## 11) Troubleshooting we hit in this project

### 11.1 `site can't be reached` for `3030` / `9091`

Check:

```bash
docker compose ps
docker compose logs prometheus-server --tail=100
docker compose logs grafana-server --tail=100
```

Typical causes:

- containers never started due earlier name conflict
- compose start failed mid-way

### 11.2 Container-name conflict errors

Error pattern:

- `The container name "/config-server" is already in use`

Fix:

```bash
docker rm -f config-server discovery-server customers-service visits-service vets-service api-gateway mysql prometheus-server grafana-server 2>/dev/null || true
docker compose up -d --build
```

### 11.3 App endpoints on `8080-8083` unreachable

Usually caused by startup failures in app services.

Fix path:

1. Check config-server logs
2. Check each service logs
3. Restart dependent services after config-server is healthy

## 12) Shutdown

```bash
docker compose down
```

Optional full cleanup:

```bash
docker compose down -v --remove-orphans
```

