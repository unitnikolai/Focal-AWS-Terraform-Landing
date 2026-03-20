locals {
  cognito_domain       = "https://focal-auth-portal.auth.us-east-2.amazoncognito.com"
  cognito_client_id    = aws_cognito_user_pool_client.client.id
  cognito_user_pool_id = aws_cognito_user_pool.main.id
  app_url              = "https://main.deu6lm3uucumx.amplifyapp.com"
  callback_url         = "${aws_apigatewayv2_api.auth.api_endpoint}/oauth2/callback"
}

resource "aws_iam_role" "auth_lambda_exec" {
    name = "auth-lambda-exec-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "auth_lambda_basic" {
  role       = aws_iam_role.auth_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "auth_lambda_vpc" {
  role       = aws_iam_role.auth_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "oauth2_callback" {
    function_name = "oAuth2Callback"
    runtime =  "nodejs20.x"
    architectures = ["arm64"]
    handler = "index.handler"
    role = aws_iam_role.auth_lambda_exec.arn
    timeout = 10
    filename = "lambdas.zip"
    vpc_config {
        subnet_ids = local.private_subnet_ids
        security_group_ids = [aws_security_group.lambda_sg.id]
    }
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

resource "aws_lambda_function" "oauth2_authorizer" {
    function_name = "oAuth2Authorizer"
    runtime = "nodejs20.x"
    architectures = ["arm64"]
    handler = "index.handler"
    role = aws_iam_role.auth_lambda_exec.arn
    timeout = 10
    filename = "lambdas.zip"
    vpc_config {
      subnet_ids = local.private_subnet_ids
      security_group_ids = [aws_security_group.lambda_sg.id]
    }
    environment {
      variables = {
        USER_POOL_ID = local.cognito_user_pool_id
        COGNITO_CLIENT_ID = local.cognito_client_id
      }
    }
    lifecycle {
      ignore_changes = [ filename, source_code_hash, last_modified ]
    }
}

resource "aws_lambda_permission" "oauth2_authorizer_apigw"{
    statement_id  = "AllowAPIGatewayAuthorizer"
    action        = "lambda:InvokeFunction"
    function_name = aws_lambda_function.oauth2_authorizer.function_name
    principal     = "apigateway.amazonaws.com"
    source_arn    = "${aws_apigatewayv2_api.auth.execution_arn}/*/*"
}

resource "aws_apigatewayv2_api" "auth" {
    name = "focal-auth-api"
    protocol_type = "HTTP"
    cors_configuration {
      allow_origins = [local.app_url, "http://localhost:3000"]
      allow_methods = ["GET", "POST", "OPTIONS"]
      allow_headers = ["content=type", "x-csrd-token"]
      allow_credentials = true
      max_age = 300
    }
}

resource "aws_apigatewayv2_stage" "default" {
    api_id = aws_apigatewayv2_api.auth.id
    name = "$default"
    auto_deploy = true
}

resource "aws_apigatewayv2_integration" "oauth2_callback" {
  api_id                 = aws_apigatewayv2_api.auth.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.oauth2_callback.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "oauth2_callback" {
  api_id    = aws_apigatewayv2_api.auth.id
  route_key = "GET /oauth2/callback"
  target    = "integrations/${aws_apigatewayv2_integration.oauth2_callback.id}"
}
resource "aws_apigatewayv2_authorizer" "oauth2" {
  api_id          = aws_apigatewayv2_api.auth.id
  authorizer_type = "REQUEST"
  authorizer_uri  = aws_lambda_function.oauth2_authorizer.invoke_arn
  name            = "oAuth2Authorizer"

  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  authorizer_result_ttl_in_seconds  = 0

  # Uncomment when enabling caching in prod:
  # identity_sources = [
  #   "$request.header.cookie",
  #   "$request.header.x-csrf-token"
  # ]
}