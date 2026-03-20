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

resource "aws_ssm_parameter" "github_runner_pat" {
  count = var.enable_github_runner && var.github_runner_pat != "" ? 1 : 0

  name      = var.github_runner_pat_parameter_name
  type      = "SecureString"
  value     = var.github_runner_pat
  overwrite = true
  tags       = var.default_tags
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

resource "aws_iam_role_policy" "github_runner_ssm_param" {
  count = var.enable_github_runner ? 1 : 0

  name = "${var.cluster_name}-github-runner-ssm-parameter-read"
  role = aws_iam_role.github_runner_ec2[0].name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${trim(var.github_runner_pat_parameter_name, "/")}"
      }
    ]
  })
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
  user_data                   = <<-USERDATA
    #!/bin/bash
    set -euo pipefail

    REGION="${var.region}"
    ORG="${var.github_org}"
    REPO="${var.github_repo}"
    PARAM_NAME="${var.github_runner_pat_parameter_name}"
    RUNNER_DIR="/opt/actions-runner"
    RUNNER_USER="ec2-user"

    if [ -f "$RUNNER_DIR/.runner" ]; then
      exit 0
    fi

    dnf -y install curl jq tar gzip

    mkdir -p "$RUNNER_DIR"
    chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"

    cd "$RUNNER_DIR"
    LATEST="$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name)"
    VERSION="${LATEST#v}"
    if [ ! -f "actions-runner-linux-x64-${VERSION}.tar.gz" ]; then
      curl -s -L -o "actions-runner-linux-x64-${VERSION}.tar.gz" \
        "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz"
    fi
    tar xzf "actions-runner-linux-x64-${VERSION}.tar.gz"

    PAT="$(aws ssm get-parameter --name "$PARAM_NAME" --with-decryption --region "$REGION" --query Parameter.Value --output text)"
    if [ -z "$PAT" ] || [ "$PAT" = "None" ]; then
      echo "Missing GitHub PAT in SSM parameter: $PARAM_NAME"
      exit 1
    fi

    REG_TOKEN="$(curl -s -X POST \
      -H "Authorization: token $PAT" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/$ORG/$REPO/actions/runners/registration-token" | jq -r .token)"

    if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" = "null" ]; then
      echo "Failed to obtain GitHub runner registration token."
      exit 1
    fi

    su - "$RUNNER_USER" -c "$RUNNER_DIR/config.sh --url https://github.com/$ORG/$REPO --token $REG_TOKEN --unattended --name ${var.cluster_name}-runner-$(hostname) --labels self-hosted,linux,aws-vpc --replace"

    "$RUNNER_DIR/svc.sh" install
    "$RUNNER_DIR/svc.sh" start
USERDATA

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
