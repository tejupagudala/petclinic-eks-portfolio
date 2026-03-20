locals {
  ssm_endpoint_services = [
    "ssm",
    "ec2messages",
    "ssmmessages",
  ]
}

resource "aws_security_group" "ssm_endpoints" {
  count       = var.enable_github_runner ? 1 : 0
  name        = "${var.cluster_name}-ssm-endpoints-sg"
  description = "Allow VPC access to SSM interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.default_tags, {
    Name = "${var.cluster_name}-ssm-endpoints-sg"
  })
}

resource "aws_vpc_endpoint" "ssm_interface" {
  for_each = var.enable_github_runner ? toset(local.ssm_endpoint_services) : toset([])

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.default_tags, {
    Name = "${var.cluster_name}-${each.value}-endpoint"
  })
}
