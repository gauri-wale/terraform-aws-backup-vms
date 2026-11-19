variable "aws_region" {
  description = "AWS region containing the EC2 instances."
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Short name used for AWS resource names."
  type        = string
  default     = "ec2-backup"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,31}$", var.project_name))
    error_message = "project_name must be 3-32 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "instance_ids" {
  description = "EC2 instance IDs to back up."
  type        = list(string)

  validation {
    condition = (
      length(var.instance_ids) == 4 &&
      alltrue([for id in var.instance_ids : can(regex("^i-[0-9a-f]{8}([0-9a-f]{9})?$", id))])
    )
    error_message = "Provide exactly four valid EC2 instance IDs."
  }
}

variable "backup_schedule" {
  description = "AWS Backup cron schedule in UTC."
  type        = string
  default     = "cron(0 2 ? * * *)"
}

variable "cold_storage_after_days" {
  description = "Move recovery points to cold storage after this many days."
  type        = number
  default     = 30

  validation {
    condition     = var.cold_storage_after_days >= 30
    error_message = "AWS Backup cold storage requires at least 30 days."
  }
}

variable "delete_after_days" {
  description = "Delete recovery points after this many days."
  type        = number
  default     = 1095

  validation {
    condition     = var.delete_after_days > var.cold_storage_after_days
    error_message = "delete_after_days must be greater than cold_storage_after_days."
  }
}

variable "tags" {
  description = "Additional tags applied to Terraform-managed AWS resources."
  type        = map(string)
  default = {
    Environment = "Production"
    Service     = "Tooling"
  }
}
