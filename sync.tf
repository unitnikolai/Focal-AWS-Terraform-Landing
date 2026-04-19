resource "aws_cloudwatch_event_rule" "organization_joined" {
  name = "organization-joined-rule"
  event_pattern = jsonencode({
    source      = ["focal.app"]
    "detail-type" = ["organization_joined"]
  })
}

resource "aws_cloudwatch_event_target" "sync_membership_lambda" {
  rule      = aws_cloudwatch_event_rule.organization_joined.name
  target_id = "syncMembershipLambda"
  arn       = aws_lambda_function.update_org_membership.arn
}

resource "aws_lambda_permission" "sync_membership_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_org_membership.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.organization_joined.arn
}

resource "aws_dynamodb_table" "membership" {
  name         = "org-memberships"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

resource "aws_lambda_function" "update_org_membership" {
  function_name    = "update-org-membership"
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = "lambdas.zip"
  source_code_hash = filebase64sha256("lambdas.zip")
  role             = aws_iam_role.lambda_role.arn
  timeout          = 10

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
      s3_bucket,
      s3_key
    ]
  }

  environment {
    variables = {
      MEMBERSHIP_TABLE = aws_dynamodb_table.membership.name
    }
  }
}

resource "aws_vpc_endpoint" "eventbridge" {
  vpc_id              = aws_vpc.app_vpc.id
  service_name        = "com.amazonaws.us-east-2.events"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
}