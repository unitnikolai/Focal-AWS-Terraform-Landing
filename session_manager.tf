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

  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

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
      MEMBERSHIP_TABLE = aws_dynamodb_table.membership.name
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
      SESSIONS_TABLE   = aws_dynamodb_table.mdm_sessions.name
      MEMBERSHIP_TABLE = aws_dynamodb_table.membership.name
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
      SESSIONS_TABLE   = aws_dynamodb_table.mdm_sessions.name
      MEMBERSHIP_TABLE = aws_dynamodb_table.membership.name
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


//AppSync Session Ingestion sync w/dynamoDB stream

resource "aws_lambda_function" "stream_handler"{
  function_name = "dynamodb-stream-handler"
  runtime = "nodejs20.x"
  handler = "index.handler"
  role = aws_iam_role.lambda_role.arn
  filename = "lambdas.zip"

  lifecycle {
    ignore_changes = [filename, source_code_hash, s3_bucket, s3_key]
  }

  environment {
    variables = {
      APPSYNC_ENDPOINT = aws_appsync_graphql_api.dashboard.uris["GRAPHQL"]
      APPSYNC_REGION   = "us-east-2"
    }
  }
}

resource "aws_lambda_event_source_mapping" "dynamodb_trigger"{
  event_source_arn = aws_dynamodb_table.mdm_sessions.stream_arn
  function_name = aws_lambda_function.stream_handler.arn
  starting_position = "LATEST"
  batch_size = 100
}

resource "aws_appsync_graphql_api" "dashboard"{
  name = "dashboard-api"
  authentication_type = "AMAZON_COGNITO_USER_POOLS"

  user_pool_config {
    user_pool_id = aws_cognito_user_pool.main.id
    default_action = "ALLOW"
    aws_region = "us-east-2"
  }

  additional_authentication_provider {
    authentication_type = "AWS_IAM"
  }

  schema = <<EOF
  type Session @aws_iam @aws_cognito_user_pools {
    session_id: ID!
    user_id: String!
    full_name: String
    org_id: String!
    group_id: String
    device_name: String
    created_at: String
    status: String
    status_since: String
    ttl: Int
  }
  type DeviceCommand @aws_cognito_user_pools {
    session_id: ID!
    command: String!
    org_id: String!
  }
  type Mutation {
    publishSessionUpdate(
      session_id: ID!
      user_id: String!
      full_name: String
      org_id: String!
      group_id: String
      device_name: String 
      status: String
      status_since: String
      created_at: String
      ttl: Int
    ): Session @aws_iam
    publishDeviceCommand(
      session_id: ID!
      org_id: String!
    ): DeviceCommand @aws_cognito_user_pools
  }
  type Subscription {
    onSessionUpdated(org_id: String!): Session
      @aws_subscribe(mutations: ["publishSessionUpdate"])
    onDeviceCommand(session_id: ID!): DeviceCommand
      @aws_subscribe(mutations: ["publishDeviceCommand"])
  }
  type Query{
    _empty: String
  }
  EOF
}



resource "aws_iam_role" "appsync_role" {
  name = "appsync-datasource-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "appsync.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "appsync_dynamo" {
  name = "appsync-dynamodb-access"
  role = aws_iam_role.appsync_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:UpdateItem"
      ]
      Resource = [
        aws_dynamodb_table.membership.arn,
        "${aws_dynamodb_table.membership.arn}/index/*",
        aws_dynamodb_table.mdm_sessions.arn,
        "${aws_dynamodb_table.mdm_sessions.arn}/index/*"
      ]
    }]
  })
}

resource "aws_appsync_datasource" "membership_table" {
  api_id           = aws_appsync_graphql_api.dashboard.id
  name             = "MembershipTable"
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.membership.name
    region     = "us-east-2"
  }

  service_role_arn = aws_iam_role.appsync_role.arn
}

resource "aws_appsync_datasource" "sessions_table" {
  api_id           = aws_appsync_graphql_api.dashboard.id
  name             = "SessionsTable"
  type             = "AMAZON_DYNAMODB"

  dynamodb_config {
    table_name = aws_dynamodb_table.mdm_sessions.name
    region     = "us-east-2"
  }

  service_role_arn = aws_iam_role.appsync_role.arn
}

resource "aws_appsync_datasource" "none" {
  api_id = aws_appsync_graphql_api.dashboard.id
  name   = "NoneDataSource"
  type   = "NONE"
}

resource "aws_appsync_resolver" "publish_session_update" {
  api_id      = aws_appsync_graphql_api.dashboard.id
  type        = "Mutation"
  field       = "publishSessionUpdate"
  data_source = aws_appsync_datasource.none.name

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }

  code = file("resolvers/publish_session_update.js")
}

resource "aws_appsync_resolver" "on_session_updated" {
  api_id      = aws_appsync_graphql_api.dashboard.id
  type        = "Subscription"
  field       = "onSessionUpdated"
  data_source = aws_appsync_datasource.membership_table.name
  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }

  code = file("resolvers/on_event_published.js")
}

resource "aws_appsync_resolver" "publish_device_command" {
  api_id = aws_appsync_graphql_api.dashboard.id
  type   = "Mutation"
  field  = "publishDeviceCommand"
  kind   = "PIPELINE"

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }

  code = file("resolvers/publish_device_command.js")

  pipeline_config {
    functions = [
      aws_appsync_function.check_admin.function_id,
      aws_appsync_function.update_session_status.function_id,
    ]
  }
}

resource "aws_appsync_function" "check_admin" {
  api_id      = aws_appsync_graphql_api.dashboard.id
  name        = "CheckAdmin"
  data_source = aws_appsync_datasource.membership_table.name

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }

  code = file("resolvers/check_admin.js")
}

resource "aws_appsync_function" "update_session_status" {
  api_id      = aws_appsync_graphql_api.dashboard.id
  name        = "UpdateSessionStatus"
  data_source = aws_appsync_datasource.sessions_table.name

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }

  code = file("resolvers/update_session_status.js")
}

resource "aws_appsync_resolver" "on_device_command" {
  api_id      = aws_appsync_graphql_api.dashboard.id
  type        = "Subscription"
  field       = "onDeviceCommand"
  data_source = aws_appsync_datasource.none.name

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }

  code = file("resolvers/on_device_command.js")
}