output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs in AZ order. Internet-facing load balancers land here"
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "Private-app subnet IDs in AZ order. EKS control plane ENIs and every nodegroup go here"
  value       = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  description = "Private-data subnet IDs in AZ order. RDS subnet group goes here"
  value       = aws_subnet.data[*].id
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs (one entry when nat_per_az = false)"
  value       = aws_nat_gateway.this[*].id
}
