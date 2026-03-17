locals {
  github_runner_subnet_id_effective = var.github_runner_subnet_id != "" ? var.github_runner_subnet_id : module.vpc.private_subnet_ids[0]
}

data "aws_ami" "github_runner" {
  count       = var.enable_github_runner && var.github_runner_ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_security_group" "github_runner" {
  count       = var.enable_github_runner ? 1 : 0
  name        = "${var.cluster_name}-github-runner-sg"
  description = "Security group for GitHub self-hosted runner"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = var.github_runner_allowed_ssh_cidrs
    content {
      description = "Optional SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "Allow outbound internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.default_tags, {
    Name = "${var.cluster_name}-github-runner-sg"
  })
}

resource "aws_iam_role" "github_runner_ec2" {
  count = var.enable_github_runner ? 1 : 0
  name  = "${var.cluster_name}-github-runner-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.default_tags
}

resource "aws_iam_role_policy_attachment" "github_runner_ssm" {
  count      = var.enable_github_runner ? 1 : 0
  role       = aws_iam_role.github_runner_ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "github_runner" {
  count = var.enable_github_runner ? 1 : 0
  name  = "${var.cluster_name}-github-runner-profile"
  role  = aws_iam_role.github_runner_ec2[0].name
}

resource "aws_instance" "github_runner" {
  count                       = var.enable_github_runner ? 1 : 0
  ami                         = var.github_runner_ami_id != "" ? var.github_runner_ami_id : data.aws_ami.github_runner[0].id
  instance_type               = var.github_runner_instance_type
  subnet_id                   = local.github_runner_subnet_id_effective
  vpc_security_group_ids      = [aws_security_group.github_runner[0].id]
  iam_instance_profile        = aws_iam_instance_profile.github_runner[0].name
  key_name                    = var.github_runner_key_name != "" ? var.github_runner_key_name : null
  associate_public_ip_address = false

  root_block_device {
    volume_size = var.github_runner_root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.default_tags, {
    Name = "${var.cluster_name}-github-runner"
    Role = "github-self-hosted-runner"
  })

  depends_on = [aws_iam_role_policy_attachment.github_runner_ssm]
}
