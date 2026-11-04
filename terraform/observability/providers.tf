terraform {
  required_version = ">= 1.5"

  required_providers {
    elasticstack = {
      source  = "elastic/elasticstack"
      version = "~> 0.16"
    }
  }
}

provider "elasticstack" {
  kibana {
    endpoints = ["https://localhost:5601"]
    insecure  = true
  }
}
