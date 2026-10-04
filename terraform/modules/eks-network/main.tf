# Networking account — VPC for an EKS cluster with a public front-end and a private back-end.
# Three tiers x N AZs (see docs/architecture/eks-landing-zone-lld.drawio, tab 1):
#   public : ALB + NAT only     rt-public  0.0.0.0/0 -> IGW
#   app    : EKS nodes + pods   rt-app-N   0.0.0.0/0 -> NAT in the same AZ
#   data   : RDS                rt-data    no default route
# In a multi-account landing zone these subnets would be shared to the workload
# account with aws_ram_resource_share. This build is single-account.

# ---------------------------------------------------------------- VPC + IGW

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

# ---------------------------------------------------------------- subnets (3 tiers x N AZs)

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = false # ALB and NAT get their public IPs explicitly; nothing else should

  tags = merge(var.tags, {
    Name                                        = "${var.name}-public-${var.availability_zones[count.index]}"
    Tier                                        = "public"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1" # internet-facing load balancers land here
  })
}

resource "aws_subnet" "app" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.app_subnet_cidrs[count.index]

  tags = merge(var.tags, {
    Name                                        = "${var.name}-app-${var.availability_zones[count.index]}"
    Tier                                        = "app"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1" # internal load balancers land here
  })
}

resource "aws_subnet" "data" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.data_subnet_cidrs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-data-${var.availability_zones[count.index]}"
    Tier = "data"
  })
}

# ---------------------------------------------------------------- NAT (1 total, or 1 per AZ)

resource "aws_eip" "nat" {
  count = var.nat_per_az ? length(var.availability_zones) : 1

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-nat-${var.availability_zones[count.index]}" })
}

resource "aws_nat_gateway" "this" {
  count = var.nat_per_az ? length(var.availability_zones) : 1

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${var.availability_zones[count.index]}" })

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------- route tables

# Public: the only table with a route to the IGW. This route is what makes a subnet "public".
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, { Name = "${var.name}-rt-public" })
}

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# App: one table per AZ so each AZ egresses through its own NAT (or the single NAT when nat_per_az = false).
resource "aws_route_table" "app" {
  count = length(var.availability_zones)

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.nat_per_az ? count.index : 0].id
  }

  tags = merge(var.tags, { Name = "${var.name}-rt-app-${var.availability_zones[count.index]}" })
}

resource "aws_route_table_association" "app" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app[count.index].id
}

# Data: no routes beyond the implicit VPC-local one. No path to or from the internet exists.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rt-data" })
}

resource "aws_route_table_association" "data" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# ---------------------------------------------------------------- endpoints

data "aws_region" "current" {}

# Free gateway endpoint: node -> S3 stays on the AWS network instead of crossing the NAT.
# Pays off once images move to ECR (layers are stored in S3). Today images come from
# Docker Hub, which still egresses via NAT.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.app[*].id

  tags = merge(var.tags, { Name = "${var.name}-vpce-s3" })
}
