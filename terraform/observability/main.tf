# Every alert rule, connector and Synthetics private location in Kibana is
# defined here and applied by infra-bootstrap, so a teardown and rebuild
# restores them with no clicks.

# Built-in Server log connector: fired alerts are written to the Kibana log.
# Managed in code so it exists on every rebuild (no hand-made connectors).
resource "elasticstack_kibana_action_connector" "server_log" {
  name              = "petclinic-server-log"
  connector_type_id = ".server-log"
}

# Replaces the "Petclinic High Latency" / "Petclinic High Error Rate" rules that
# used to be imported from kubernetes/elastic/alerts/petclinic-alerts.ndjson
# (same service, environment and thresholds), plus log, CPU and memory rules.
module "api_gateway" {
  source = "../modules/observability-alerts"

  service_name  = "api-gateway"
  environment   = "portfolio"
  k8s_namespace = "petclinic"

  connector_id = elasticstack_kibana_action_connector.server_log.connector_id

  latency_threshold_ms      = 500
  error_rate_threshold_pct  = 2
  error_log_count_threshold = 5
  cpu_threshold             = 0.80
  memory_threshold          = 0.80
}

# Synthetics private location: lets monitors run from the synthetics-agent pod
# inside the cluster. Its Fleet agent policy is preconfigured with this fixed id
# in kubernetes/elastic/kibana.yaml; this registers it with Synthetics.
resource "elasticstack_kibana_synthetics_private_location" "petclinic" {
  label           = "petclinic-eks"
  agent_policy_id = "synthetics-private-location"
  tags            = ["petclinic", "managed-by-terraform"]
}

# Uptime checks that run from the in-cluster private location every minute.
resource "elasticstack_kibana_synthetics_monitor" "demo_service_internal" {
  name              = "observability-demo-service-internal"
  schedule          = 1
  timeout           = 16
  private_locations = [elasticstack_kibana_synthetics_private_location.petclinic.label]
  service_name      = "observability-demo-service"
  tags              = ["petclinic", "managed-by-terraform"]

  # In-cluster DNS: checks the service directly, independent of Traefik and DNS.
  http = {
    url           = "http://observability-demo-service.petclinic.svc.cluster.local:8084/hello"
    max_redirects = 0
    mode          = "any"
    ipv4          = true
    ipv6          = true
  }
}

resource "elasticstack_kibana_synthetics_monitor" "petclinic_public" {
  name              = "petclinic-public"
  schedule          = 1
  timeout           = 16
  private_locations = [elasticstack_kibana_synthetics_private_location.petclinic.label]
  service_name      = "api-gateway"
  tags              = ["petclinic", "managed-by-terraform"]

  # The public URL: exercises GoDaddy DNS, the Traefik NLB, TLS and the gateway.
  http = {
    url           = "https://petclinic.thedevopsportfolio.online"
    max_redirects = 0
    mode          = "any"
    ipv4          = true
    ipv6          = true
  }
}

module "observability_demo" {
  source = "../modules/observability-alerts"

  service_name  = "observability-demo-service"
  environment   = "portfolio"
  k8s_namespace = "petclinic"

  connector_id = elasticstack_kibana_action_connector.server_log.connector_id

  latency_threshold_ms      = 500
  error_rate_threshold_pct  = 2
  error_log_count_threshold = 5
  cpu_threshold             = 0.80
  memory_threshold          = 0.80
}
