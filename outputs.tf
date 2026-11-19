output "backup_vault_name" {
  description = "Name of the AWS Backup vault."
  value       = aws_backup_vault.vm_backup.name
}

output "backup_plan_id" {
  description = "ID of the AWS Backup plan."
  value       = aws_backup_plan.vm_daily.id
}

output "backup_role_arn" {
  description = "IAM role used by AWS Backup."
  value       = aws_iam_role.aws_backup.arn
}

output "protected_instance_arns" {
  description = "EC2 resource ARNs included in the backup selection."
  value       = local.instance_arns
}
