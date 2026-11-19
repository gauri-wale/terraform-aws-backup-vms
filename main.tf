terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  common_tags = merge(
    var.tags,
    {
      ManagedBy = "Terraform"
    }
  )

  instance_arns = [
    for instance_id in var.instance_ids :
    "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${instance_id}"
  ]
}

resource "aws_kms_key" "backup" {
  description             = "KMS key for AWS Backup recovery points"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_kms_alias" "backup" {
  name          = "alias/aws-backup-${var.project_name}"
  target_key_id = aws_kms_key.backup.key_id
}

resource "aws_backup_vault" "vm_backup" {
  name        = "${var.project_name}-vm-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn

  tags = local.common_tags
}

resource "aws_iam_role" "aws_backup" {
  name = "${var.project_name}-aws-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "backup.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.aws_backup.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  role       = aws_iam_role.aws_backup.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_plan" "vm_daily" {
  name = "${var.project_name}-vm-daily-plan"

  rule {
    rule_name                = "daily-backup-to-long-term"
    target_vault_name        = aws_backup_vault.vm_backup.name
    schedule                 = var.backup_schedule
    start_window             = 60
    completion_window        = 180
    enable_continuous_backup = false

    lifecycle {
      cold_storage_after = var.cold_storage_after_days
      delete_after       = var.delete_after_days
    }

    recovery_point_tags = merge(
      local.common_tags,
      {
        BackupPlan = "${var.project_name}-vm-daily-plan"
      }
    )
  }

  tags = local.common_tags
}

resource "aws_backup_selection" "four_vms" {
  name         = "${var.project_name}-four-vms"
  iam_role_arn = aws_iam_role.aws_backup.arn
  plan_id      = aws_backup_plan.vm_daily.id

  resources = local.instance_arns
}