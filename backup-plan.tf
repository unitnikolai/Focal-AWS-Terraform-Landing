resource "aws_backup_vault" "backup_vault" {
  name = "focal-backup-vault"
}

resource "aws_iam_role" "backup_role" {
  name = "aws-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup_role_policy" {
  role       = aws_iam_role.backup_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_plan" "usertable_backup_plan"{
    name = "usertable_backup_plan"

    rule {
        rule_name = "dynamodb_usertable_backup_rule"
        target_vault_name = aws_backup_vault.backup_vault.name
        schedule = "cron(0 12 * * ? *)" # Daily at 12:00 PM UTC

        lifecycle {
          delete_after = 14
        }
    }
}

resource "aws_backup_selection" "usertable_backup_selection"{
    name = "usertable_backup_selection"
    plan_id = aws_backup_plan.usertable_backup_plan.id
    iam_role_arn = aws_iam_role.backup_role.arn

    selection_tag {
        type = "STRINGEQUALS"
        key = "backup"
        value = "true"
    }

    resources = [
        aws_dynamodb_table.membership.arn,
    ]
}