variable "service_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "k8s_namespace" {
  type    = string
  default = "petclinic"
}

variable "connector_id" {
  type = string
}

variable "latency_threshold_ms" {
  type    = number
  default = 500
}

variable "error_rate_threshold_pct" {
  type    = number
  default = 2
}

variable "error_log_count_threshold" {
  type    = number
  default = 5
}

variable "cpu_threshold" {
  type    = number
  default = 0.80
}

variable "memory_threshold" {
  type    = number
  default = 0.80
}
