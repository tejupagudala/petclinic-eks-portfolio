# Every alert rule and connector in Kibana is defined here and applied by
# infra-bootstrap, so a teardown and rebuild restores alerting with no clicks.

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
