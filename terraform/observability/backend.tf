terraform {
  backend "s3" {
    bucket       = "petclinic-terraform-state-589077667712"
    key          = "observability/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
