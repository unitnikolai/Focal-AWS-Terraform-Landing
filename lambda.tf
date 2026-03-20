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

