module "observability_demo" {
  source = "../modules/observability-alerts"

  service_name  = "observability-demo-service"
  environment   = "portfolio"
  k8s_namespace = "petclinic"

  connector_id = "test-apm-server-log"

  latency_threshold_ms      = 500
  error_rate_threshold_pct  = 2
  error_log_count_threshold = 5
  cpu_threshold             = 0.80
  memory_threshold          = 0.80
}
