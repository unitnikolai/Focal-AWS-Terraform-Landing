resource "aws_dynamodb_table" "mdm_sessions" {
  name         = "mdm_sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }
  attribute {
    name = "user_id"
    type = "S"
  }
  attribute {
    name = "org_id"
    type = "S"
  }
  attribute {
    name = "group_id"
    type = "S"
  }

  attribute {
    name = "device_name"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }
  

  attribute {
    name = "status_since"
    type = "S"
  }

  global_secondary_index {
    name            = "user-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "user_id"
      key_type       = "HASH"
    }
    key_schema {
      attribute_name = "created_at"
      key_type       = "RANGE"
    }
  }

  global_secondary_index {
    name            = "org-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "org_id"
      key_type       = "HASH"
    }
    key_schema {
      attribute_name = "status_since"
      key_type       = "RANGE"
    }
  }

  global_secondary_index {
    name            = "group-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "group_id"
      key_type       = "HASH"
    }
    key_schema {
      attribute_name = "status_since"
      key_type       = "RANGE"
    }
  }

  global_secondary_index {
    name            = "device-index"
    projection_type = "ALL"

    key_schema {
      attribute_name = "device_name"
      key_type       = "HASH"
    }
    key_schema {
      attribute_name = "status_since"
      key_type       = "RANGE"
    }
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = {
    Name = "MDM Sessions Table"
  }
}


resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id              = aws_vpc.app_vpc.id
  service_name        = "com.amazonaws.us-east-2.dynamodb"
  vpc_endpoint_type   = "Gateway"
  route_table_ids     = [aws_vpc.app_vpc.main_route_table_id]

  tags = {
    Name = "DynamoDB VPC Endpoint"
  }
}



resource "aws_lambda_function" "get-sessions" {
  function_name = "get-sessions"
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
      SESSIONS_TABLE = aws_dynamodb_table.mdm_sessions.name
    }
  }
}
resource "aws_apigatewayv2_integration" "get-sessions" {
  api_id                 = aws_apigatewayv2_api.auth.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get-sessions.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get-sessions" {
  api_id    = aws_apigatewayv2_api.auth.id
  route_key = "GET /session/pull"
  target    = "integrations/${aws_apigatewayv2_integration.get-sessions.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.oauth2.id
  authorization_type = "CUSTOM"
}

resource "aws_lambda_permission" "apigw_get-sessions" {
  statement_id  = "AllowAPIGatewayGetSessions"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get-sessions.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.auth.execution_arn}/*/*"
}
resource "aws_lambda_function" "create-session" {
  function_name = "create-session"
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
      SESSIONS_TABLE = aws_dynamodb_table.mdm_sessions.name
    }
  }
}

resource "aws_apigatewayv2_integration" "create-session" {
  api_id                 = aws_apigatewayv2_api.auth.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create-session.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create-session" {
  api_id    = aws_apigatewayv2_api.auth.id
  route_key = "POST /session/create"
  target    = "integrations/${aws_apigatewayv2_integration.create-session.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.oauth2.id
  authorization_type = "CUSTOM"
}

resource "aws_lambda_permission" "apigw_create-session" {
  statement_id  = "AllowAPIGatewayCreateSession"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create-session.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.auth.execution_arn}/*/*"
}



resource "aws_lambda_function" "update-session" {
  function_name = "update-session"
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
      SESSIONS_TABLE = aws_dynamodb_table.mdm_sessions.name
    }
  }
}

resource "aws_apigatewayv2_integration" "update-session" {
  api_id                 = aws_apigatewayv2_api.auth.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.update-session.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "update-session" {
  api_id    = aws_apigatewayv2_api.auth.id
  route_key = "POST /session/update"
  target    = "integrations/${aws_apigatewayv2_integration.update-session.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.oauth2.id
  authorization_type = "CUSTOM"
}

resource "aws_lambda_permission" "apigw_update-session" {
  statement_id  = "AllowAPIGatewayUpdateSession"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update-session.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.auth.execution_arn}/*/*"
}