resource "aws_iam_role" "lambda_role" {
  name = "post-confirmation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_lambda_permission" "cognito_post_confirmation" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"

  function_name = aws_lambda_function.post_confirmation.arn

  principal = "cognito-idp.amazonaws.com"

}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "post_confirmation" {
  function_name = "cognito-post-confirmation"

  runtime = "nodejs20.x"
  handler = "postconfirmation.handler"
  filename = "lambdas.zip"
  source_code_hash = filebase64sha256("lambdas.zip")
  role = aws_iam_role.lambda_role.arn

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
      DB_USER = var.db_username
      DB_PASSWORD = var.db_password
      DB_NAME = "focal_db_1"
      DB_HOST = "app-db-writer.cr2244yo4wbf.us-east-2.rds.amazonaws.com"
      DB_SECRET_ID = "prod/focal_rds_1"
    }
  }
} 

resource "aws_lambda_function" "pull_profile"{
  function_name = "lambda-pull_profile"
  runtime = "nodejs20.x"
  architectures = ["arm64"]
  handler = "index.handler"
  role = aws_iam_role.auth_lambda_exec.arn
  timeout = 10
  filename = "lambas.zip"
  environment {
    variables = {
      COGNITO_DOMAIN    = local.cognito_domain
      COGNITO_CLIENT_ID = local.cognito_client_id
      CALLBACK_URL      = local.callback_url
      APP_URL           = local.app_url
    }
  }
  lifecycle {
    ignore_changes = [ filename, source_code_hash, last_modified ]
  }
}