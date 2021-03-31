provider "aws" {
  # profile = "default"
  region = var.region
}

## Another Workspaces ##
# Workspace - vpc
data "terraform_remote_state" "vpc" {
  backend = "remote"
  config = {
    organization = "terraexam"
    workspaces = {
      name = "terraexam-aws-vpc"
    }
  }
}

# Workspace - security group
data "terraform_remote_state" "sg" {
  backend = "remote"
  config = {
    organization = "terraexam"
    workspaces = {
      name = "terraexam-aws-sg"
    }
  }
}

locals {
  nick = "${var.name}-postgre"

  vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  vpc_cidr_block        = data.terraform_remote_state.vpc.outputs.vpc_cidr_block
  public_subnet_ids     = data.terraform_remote_state.vpc.outputs.public_subnets
  private_subnet_ids    = data.terraform_remote_state.vpc.outputs.private_subnets
  database_subnet_ids   = data.terraform_remote_state.vpc.outputs.database_subnets
  database_subnet_group = data.terraform_remote_state.vpc.outputs.database_subnet_group

  bastion_security_group_ids = [data.terraform_remote_state.sg.outputs.bastion_security_group_id]
  alb_security_group_ids     = [data.terraform_remote_state.sg.outputs.alb_security_group_id]
  was_security_group_ids     = [data.terraform_remote_state.sg.outputs.was_security_group_id]
  db_security_group_ids      = [data.terraform_remote_state.sg.outputs.db_security_group_id]
}

#####
# DB
#####
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "2.34.0"

  identifier = local.nick

  # All available versions: 
  engine                = var.rds_engine
  engine_version        = var.rds_engine_version
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_encrypted     = var.rds_storage_encrypted

  # kms_key_id        = "arm:aws:kms:<region>:<account id>:key/<kms key id>"
  name                   = var.rds_db_name
  username               = var.rds_username
  password               = var.rds_password
  port                   = var.rds_port
  vpc_security_group_ids = local.db_security_group_ids
  maintenance_window     = var.rds_maintenance_window
  backup_window          = var.rds_backup_window
  multi_az               = var.rds_multi_az

  # disable backups to create DB faster
  backup_retention_period = var.rds_backup_retention_period

  tags = var.tags

  #   alert, audit, error, general, listener, slowquery, trace, postgresql (PostgreSQL), upgrade (PostgreSQL)
  enabled_cloudwatch_logs_exports = var.rds_enabled_cloudwatch_logs_exports

  # DB subnet group
  # db_subnet_group_name = local.database_subnet_group
  create_db_subnet_group = true
  subnet_ids             = local.database_subnet_ids

  # DB parameter group
  family = var.rds_param_family

  # DB option group
  major_engine_version = var.rds_option_major_engine_version

  # Snapshot name upon DB deletion
  # final_snapshot_identifier = join("", [var.name, "-last-", formatdate("YYYYMMMDDhhmmss", timestamp())])
  skip_final_snapshot = var.rds_skip_final_snapshot

  # Database Deletion Protection
  deletion_protection = var.rds_deletion_protection

  # parameters = var.rds_parameters
  # options    = var.rds_options

  ## Enhanced monitoring ##
  ##
  # The interval, in seconds, between points when Enhanced Monitoring metrics are collected for the DB instance. 
  # To disable collecting Enhanced Monitoring metrics, specify 0. 
  # The default is 0. Valid Values: 0, 1, 5, 10, 15, 30, 60.
  monitoring_interval = var.rds_monitoring_interval

  # Create IAM role with a defined name that permits RDS to send enhanced monitoring metrics to CloudWatch Logs.
  create_monitoring_role = var.rds_create_monitoring_role

  # Name of the IAM role which will be created when create_monitoring_role is enabled.
  monitoring_role_name = var.rds_monitoring_role_name

  ## Performance Insights ##
  ##
  # Specifies whether Performance Insights are enabled
  performance_insights_enabled = var.rds_performance_insights_enabled

  # The amount of time in days to retain Performance Insights data. Either 7 (7 days) or 731 (2 years).
  performance_insights_retention_period = var.rds_performance_insights_retention_period

  # The ARN for the KMS key to encrypt Performance Insights data.
  # performance_insights_kms_key_id = ''
}