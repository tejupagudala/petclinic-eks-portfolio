resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS storage encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = var.default_tags
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.cluster_name}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_db_subnet_group" "petclinic" {
  name       = "${var.cluster_name}-rds-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = var.default_tags
}

resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Allow MySQL from EKS workloads"
  vpc_id      = module.vpc.vpc_id

  tags = var.default_tags
}

resource "aws_security_group_rule" "eks_to_rds" {
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_db_instance" "petclinic" {
  identifier              = "${var.cluster_name}-mysql"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.rds_instance_class
  allocated_storage       = var.rds_allocated_storage
  storage_type            = "gp3"
  storage_encrypted       = true
  kms_key_id              = aws_kms_key.rds.arn
  db_name                 = "petclinic"

  username                    = var.rds_username
  manage_master_user_password = true

  db_subnet_group_name    = aws_db_subnet_group.petclinic.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 1
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = var.default_tags
}
