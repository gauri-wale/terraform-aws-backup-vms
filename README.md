# AWS EC2 long-term backups with Terraform

This configuration protects four EC2 instances in `eu-west-2`. Set their IDs in a local `terraform.tfvars` file; do not commit real instance IDs or hostnames.

Start from `terraform.tfvars.example` and replace its placeholder values.

It creates:

1. A customer-managed KMS key and encrypted AWS Backup vault.
2. An IAM service role for AWS Backup.
3. A daily backup plan scheduled at 02:00 UTC.
4. A backup selection containing the four instance ARNs.
5. A lifecycle that moves recovery points to cold storage after 30 days and deletes them after 1,095 days (3 years).

## 1. Install the tools

Install and add to `PATH`:

- Visual Studio Code
- HashiCorp Terraform
- AWS CLI v2
- VS Code Terraform extension (`HashiCorp Terraform`)
- Optional: VS Code AWS Toolkit extension

Windows winget examples:

```powershell
winget install -e --id HashiCorp.Terraform
winget install -e --id Amazon.AWSCLI
```

Restart VS Code after installation.

## 2. Connect AWS CLI to AWS

Authenticate with the AWS CLI profile you use for AWS login:

```powershell
$profile = "<profile-name>"
aws login --profile $profile
$json = aws configure export-credentials --profile $profile --format process
if ($LASTEXITCODE -ne 0) { throw "Could not export AWS credentials." }
$creds = $json | ConvertFrom-Json
$env:AWS_ACCESS_KEY_ID = $creds.AccessKeyId
$env:AWS_SECRET_ACCESS_KEY = $creds.SecretAccessKey
$env:AWS_SESSION_TOKEN = $creds.SessionToken
aws sts get-caller-identity
```

The AWS user or role must be allowed to create IAM roles and policies, KMS keys and aliases, EC2 snapshot resources, and AWS Backup resources.

The exported credentials are temporary. Refresh them and re-export after they expire. Do not put credentials in Terraform files.

## 3. Open the project

Open the project directory in VS Code, then switch the terminal to that directory:

```text
<project-folder>
```

Create the local variable file and replace the example instance IDs with your four EC2 instance IDs:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

If you are using temporary credentials, export them as shown above. Set the region:

```powershell
$env:AWS_REGION = "eu-west-2"
```

## 4. Initialize and review

```powershell
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
```

Review the plan and confirm that it creates:

- 1 KMS key
- 1 backup vault
- 1 IAM role
- 1 backup plan
- 1 backup selection

## 5. Apply

```powershell
terraform apply tfplan
```

The next backup starts according to the 02:00 UTC schedule. To start one immediately, use the AWS Backup console:

In the AWS Backup console:

1. Open **AWS Backup**.
2. Choose **Protected resources** and confirm all four instance IDs.
3. Choose **On-demand backup**.
4. Select the instance, `ec2-backup-vm-backup-vault`, and `ec2-backup-vm-daily-plan`.
5. Start the backup and confirm it reaches `Completed`.

## 6. Verify

In AWS Backup:

- **Protected resources** shows the four EC2 instances.
- **Backup jobs** shows successful daily jobs.
- **Recovery points** shows encrypted recovery points in the vault.

In AWS CLI:

```powershell
aws backup list-recovery-points-by-backup-vault `
  --region eu-west-2 `
  --backup-vault-name ec2-backup-vm-backup-vault
```

## 7. Restore one EC2 instance

Before restoring, decide whether you need to preserve the original instance, network interface, Elastic IP, IAM role, security groups, and EBS volume settings. AWS Backup restores an EC2 recovery point to a new EBS-backed EC2 configuration; it does not restore every original console setting automatically.

For a test restore:

1. In AWS Backup, open **Backup vaults**.
2. Open `ec2-backup-vm-backup-vault`.
3. Choose a completed recovery point.
4. Choose **Restore**.
5. Select a target subnet and security group.
6. Select or create an IAM role for the restored instance if requested.
7. Verify private IP, public IP, root volume size, and tags.
8. Start the restore and wait for completion.
9. Test the restored instance before changing DNS or production routing.

Never restore directly into production until connectivity, application services, configuration, and data are verified.

## 8. Change retention or schedule

Copy `terraform.tfvars.example` to `terraform.tfvars` and edit the local file. `terraform.tfvars` is ignored by Git:

- `backup_schedule`: AWS cron expression in UTC.
- `cold_storage_after_days`: minimum 30 for cold storage.
- `delete_after_days`: must be greater than the cold-storage period.

Then run:

```powershell
terraform plan -out=tfplan
terraform apply tfplan
```

## 9. Destroy only the Terraform backup resources

An AWS Backup vault cannot normally be deleted while recovery points exist. For a test-only setup:

```powershell
aws backup list-recovery-points-by-backup-vault `
  --region eu-west-2 `
  --backup-vault-name ec2-backup-vm-backup-vault
```

Delete recovery points individually before running `terraform destroy`, or remove Terraform resources only after your long-term retention policy is no longer needed.

## 10. Cost and safety notes

- EC2 backup uses EBS snapshots and AWS Backup storage.
- Cold storage and snapshot storage incur charges.
- The KMS key incurs usage and key charges.
- A 365-day retention period is not the same as a cross-region or cross-account disaster-recovery copy.
- For disaster recovery, add a copy action to a vault in another region and a second AWS provider alias.
- The stopped instances are intentionally not included. Add them separately with their instance IDs if they also require protection.
