locals {
  root_domain = var.domain_name                 # devops-portfolio.online
  www_domain  = "www.${var.domain_name}"        # www.devops-portfolio.online

  # Both names the site will answer on
  all_domains = [local.root_domain, local.www_domain]
}
