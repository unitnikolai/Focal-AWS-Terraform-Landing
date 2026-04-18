resource "aws_lambda_function" "profile-mobile-stats" {
  function_name = "profile-mobile-stats"
  runtime = "nodejs20.x"
  handler = "index.handler"
  filename = "lambdas.zip"
  source_code_hash = filebase64sha256("lambdas.zip")
  role = aws_iam_role.lambda_role.arn
  timeout = 10

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

resource "aws_apigatewayv2_integration" "profile-mobile-stats" {
  api_id                 = aws_apigatewayv2_api.auth.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.profile-mobile-stats.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "profile-mobile-stats" {
  api_id    = aws_apigatewayv2_api.auth.id
  route_key = "GET /profile/mobile/stats"
  target    = "integrations/${aws_apigatewayv2_integration.profile-mobile-stats.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.oauth2.id
  authorization_type = "CUSTOM"
}

resource "aws_lambda_permission" "apigw_profile-mobile-stats" {
  statement_id  = "AllowAPIGatewayProfileMobileStats"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.profile-mobile-stats.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.auth.execution_arn}/*/*"
}