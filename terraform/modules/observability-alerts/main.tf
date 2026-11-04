locals {
  tags = [
    var.service_name,
    var.environment,
    "managed-by-terraform"
  ]

  metric_filter = "k8s.namespace.name:\"${var.k8s_namespace}\" AND k8s.pod.name:${var.service_name}*"
}

resource "elasticstack_kibana_alerting_rule" "latency" {
  name         = "${var.service_name}-p95-latency"
  consumer     = "alerts"
  rule_type_id = "apm.transaction_duration"
  interval     = "1m"
  enabled      = true
  tags         = local.tags

  params = jsonencode({
    aggregationType = "95th"
    environment     = var.environment
    serviceName     = var.service_name
    transactionType = "request"
    threshold       = var.latency_threshold_ms
    windowSize      = 5
    windowUnit      = "m"

    groupBy = [
      "service.name",
      "service.environment",
      "transaction.type",
      "transaction.name"
    ]
  })

  actions {
    id    = var.connector_id
    group = "threshold_met"

    params = jsonencode({
      message = "APM latency alert: {{context.reason}}"
    })

    frequency {
      summary     = false
      notify_when = "onActionGroupChange"
    }
  }
}

resource "elasticstack_kibana_alerting_rule" "error_rate" {
  name         = "${var.service_name}-high-error-rate"
  consumer     = "alerts"
  rule_type_id = "apm.transaction_error_rate"
  interval     = "1m"
  enabled      = true
  tags         = local.tags

  params = jsonencode({
    environment = var.environment
    serviceName = var.service_name
    threshold   = var.error_rate_threshold_pct
    windowSize  = 5
    windowUnit  = "m"

    groupBy = [
      "service.name",
      "service.environment",
      "transaction.type",
      "transaction.name"
    ]
  })

  actions {
    id    = var.connector_id
    group = "threshold_met"

    params = jsonencode({
      message = "APM error-rate alert: {{context.reason}}"
    })

    frequency {
      summary     = false
      notify_when = "onActionGroupChange"
    }
  }
}

resource "elasticstack_kibana_alerting_rule" "error_logs" {
  name         = "${var.service_name}-error-log-spike"
  consumer     = "alerts"
  rule_type_id = "observability.rules.custom_threshold"
  interval     = "1m"
  enabled      = true
  tags         = local.tags

  params = jsonencode({
    criteria = [{
      comparator = ">"
      metrics = [{
        name    = "A"
        aggType = "count"
        filter  = ""
      }]
      threshold = [var.error_log_count_threshold]
      timeSize  = 5
      timeUnit  = "m"
    }]

    noDataBehavior = "recover"

    searchConfiguration = {
      index = "logs-*"

      query = {
        language = "kuery"
        query    = "service.name:\"${var.service_name}\" AND k8s.namespace.name:\"${var.k8s_namespace}\" AND (log.level:\"ERROR\" OR log.level:\"error\")"
      }
    }
  })

  actions {
    id    = var.connector_id
    group = "custom_threshold.fired"

    params = jsonencode({
      message = "Application ERROR log spike: {{context.reason}}"
    })

    frequency {
      summary     = false
      notify_when = "onActionGroupChange"
    }
  }
}

resource "elasticstack_kibana_alerting_rule" "cpu" {
  name         = "${var.service_name}-high-cpu"
  consumer     = "alerts"
  rule_type_id = "observability.rules.custom_threshold"
  interval     = "1m"
  enabled      = true
  tags         = local.tags

  params = jsonencode({
    criteria = [{
      comparator = ">"
      metrics = [{
        name    = "A"
        field   = "metrics.k8s.pod.cpu_limit_utilization"
        aggType = "avg"
        filter  = ""
      }]
      threshold = [var.cpu_threshold]
      timeSize  = 5
      timeUnit  = "m"
    }]

    noDataBehavior = "recover"

    searchConfiguration = {
      index = "metrics-*"

      query = {
        language = "kuery"
        query    = local.metric_filter
      }
    }

    groupBy = ["k8s.pod.name"]
  })

  actions {
    id    = var.connector_id
    group = "custom_threshold.fired"

    params = jsonencode({
      message = "High pod CPU: {{context.reason}}"
    })

    frequency {
      summary     = false
      notify_when = "onActionGroupChange"
    }
  }
}

resource "elasticstack_kibana_alerting_rule" "memory" {
  name         = "${var.service_name}-high-memory"
  consumer     = "alerts"
  rule_type_id = "observability.rules.custom_threshold"
  interval     = "1m"
  enabled      = true
  tags         = local.tags

  params = jsonencode({
    criteria = [{
      comparator = ">"
      metrics = [{
        name    = "A"
        field   = "metrics.k8s.container.memory_limit_utilization"
        aggType = "avg"
        filter  = ""
      }]
      threshold = [var.memory_threshold]
      timeSize  = 5
      timeUnit  = "m"
    }]

    noDataBehavior = "recover"

    searchConfiguration = {
      index = "metrics-*"

      query = {
        language = "kuery"
        query    = local.metric_filter
      }
    }

    groupBy = ["k8s.pod.name"]
  })

  actions {
    id    = var.connector_id
    group = "custom_threshold.fired"

    params = jsonencode({
      message = "High pod memory: {{context.reason}}"
    })

    frequency {
      summary     = false
      notify_when = "onActionGroupChange"
    }
  }
}
