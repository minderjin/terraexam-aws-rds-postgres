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

  bastion_security_group_ids = ["${data.terraform_remote_state.sg.outputs.bastion_security_group_id}"]
  alb_security_group_ids     = ["${data.terraform_remote_state.sg.outputs.alb_security_group_id}"]
  was_security_group_ids     = ["${data.terraform_remote_state.sg.outputs.was_security_group_id}"]
  db_security_group_ids      = ["${data.terraform_remote_state.sg.outputs.db_security_group_id}"]
}

#####
# DB
#####
module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = local.nick

  # All available versions: http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html#MySQL.Concepts.VersionMgmt
  engine            = "postgres"
  engine_version    = "12.5"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_encrypted = false

  # kms_key_id        = "arm:aws:kms:<region>:<account id>:key/<kms key id>"
  name     = "${var.name}"
  username = "postgres"
  password = "YourPwdShouldBeLongAndSecure!"
  port     = "5432"

  vpc_security_group_ids = local.db_security_group_ids

  maintenance_window = "Sat:19:00-Sat:21:00"
  backup_window      = "16:00-19:00"

  multi_az = false

  # disable backups to create DB faster
  backup_retention_period = 7

  tags = var.tags

  #   alert, audit, error, general, listener, slowquery, trace, postgresql (PostgreSQL), upgrade (PostgreSQL)
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # DB subnet group
  #   subnet_ids = database_subnet_group
  db_subnet_group_name = local.database_subnet_group
  # subnet_ids = data.aws_subnet_ids.all.ids

  # DB parameter group
  family = "postgres12"

  # DB option group
  major_engine_version = "12"

  # Snapshot name upon DB deletion
  final_snapshot_identifier = local.nick

  # Database Deletion Protection
  deletion_protection = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
}