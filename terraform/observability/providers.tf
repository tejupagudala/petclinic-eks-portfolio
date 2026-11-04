terraform {
  # backend.tf uses S3-native locking (use_lockfile), which needs Terraform 1.10+.
  required_version = ">= 1.10"

  required_providers {
    elasticstack = {
      source  = "elastic/elasticstack"
      version = "~> 0.16"
    }
  }
}

# The Kibana endpoint and credentials come from the environment, so the same
# code runs from a laptop and from infra-bootstrap:
#   KIBANA_ENDPOINT  e.g. https://127.0.0.1:5601 (a kubectl port-forward)
#   KIBANA_USERNAME  elastic
#   KIBANA_PASSWORD  from secret elastic/petclinic-logs-es-elastic-user
provider "elasticstack" {
  kibana {
    # Kibana is only reached through a kubectl port-forward on loopback. ECK's
    # self-signed certificate names the in-cluster Service, not localhost, so
    # hostname verification cannot pass. The hop that leaves the machine is
    # already inside kubectl's authenticated TLS tunnel to the API server.
    insecure = true
  }
}
