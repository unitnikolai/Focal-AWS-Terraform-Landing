resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

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
  source_arn = aws_cognito_user_pool.main.arn
  function_name = aws_lambda_function.post_confirmation.arn

  principal = "cognito-idp.amazonaws.com"

}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_eventbridge" {
  name = "eventbridge-put-events"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "events:PutEvents"
      Resource = "arn:aws:events:us-east-2:*:event-bus/default"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_secrets" {
  name = "secrets-manager-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = "arn:aws:secretsmanager:us-east-2:*:secret:prod/focal_rds_1-*"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "dynamodb-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      Resource = [
        aws_dynamodb_table.mdm_sessions.arn,
        "${aws_dynamodb_table.mdm_sessions.arn}/index/*",
        aws_dynamodb_table.membership.arn,
        "${aws_dynamodb_table.membership.arn}/index/*"
      ]
    },
    {
      Effect = "Allow"
      Action = [
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:DescribeStream",
        "dynamodb:ListStreams"
      ]
      Resource = [
        "${aws_dynamodb_table.mdm_sessions.arn}/stream/*"
      ]
    },
    {
      Effect   = "Allow"
      Action   = "appsync:GraphQL"
      Resource = "${aws_appsync_graphql_api.dashboard.arn}/types/Mutation/fields/publishSessionUpdate"
    }]
  })
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

resource "aws_lambda_function" "organization-handle" {
  function_name = "organization-handle"
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
      DB_NAME = "focal_db_1"
      DB_HOST = "app-db-writer.cr2244yo4wbf.us-east-2.rds.amazonaws.com"
      DB_SECRET_ID = "prod/focal_rds_1"
    }
  }
} 

resource "aws_apigatewayv2_integration" "organization-handle" {
  api_id                 = aws_apigatewayv2_api.auth.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.organization-handle.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "organization-handle" {
  api_id    = aws_apigatewayv2_api.auth.id
  route_key = "POST /organization/join"
  target    = "integrations/${aws_apigatewayv2_integration.organization-handle.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.oauth2.id
  authorization_type = "CUSTOM"
}

resource "aws_lambda_permission" "apigw_organization-handle" {
  statement_id  = "AllowAPIGatewayOrganizationHandle"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.organization-handle.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.auth.execution_arn}/*/*"
}

//Lambda for group selector

resource "aws_lambda_function" "group-selector" {
  function_name = "group-selector"
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
      DB_NAME = "focal_db_1"
      DB_HOST = "app-db-writer.cr2244yo4wbf.us-east-2.rds.amazonaws.com"
      DB_SECRET_ID = "prod/focal_rds_1"
    }
  }
} 

resource "aws_apigatewayv2_integration" "group-selector" {
  api_id                 = aws_apigatewayv2_api.auth.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.group-selector.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "group-selector" {
  api_id    = aws_apigatewayv2_api.auth.id
  route_key = "POST /organization/join-group"
  target    = "integrations/${aws_apigatewayv2_integration.group-selector.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.oauth2.id
  authorization_type = "CUSTOM"
}

resource "aws_lambda_permission" "apigw_group-selector" {
  statement_id  = "AllowAPIGatewayGroupSelector"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.group-selector.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.auth.execution_arn}/*/*"
}

//Profile query Lambda

resource "aws_lambda_function" "profile-query" {
  function_name = "profile-query"
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
      DB_NAME = "focal_db_1"
      DB_HOST = "app-db-writer.cr2244yo4wbf.us-east-2.rds.amazonaws.com"
      DB_SECRET_ID = "prod/focal_rds_1"
    }
  }
} 

resource "aws_apigatewayv2_integration" "profile-query" {
  api_id                 = aws_apigatewayv2_api.auth.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.profile-query.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "profile-query" {
  api_id    = aws_apigatewayv2_api.auth.id
  route_key = "GET /api/profile"
  target    = "integrations/${aws_apigatewayv2_integration.profile-query.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.oauth2.id
  authorization_type = "CUSTOM"
}

resource "aws_lambda_permission" "apigw_profile-query" {
  statement_id  = "AllowAPIGatewayProfileQuery"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.profile-query.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.auth.execution_arn}/*/*"
}

resource "aws_lambda_function" "sync_rds_admins" {
  function_name = "sync-rds-admins"
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  filename      = "lambdas.zip"
  role          = aws_iam_role.lambda_role.arn
  timeout       = 30

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
      DB_SECRET_ID     = "prod/focal_rds_1"
      MEMBERSHIP_TABLE = aws_dynamodb_table.membership.name
    }
  }
}
