resource "aws_dynamodb_table" "mdm_sessions" {
  name         = "focal-sessions-table"
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
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce_sg.id]
  private_dns_enabled = true
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
}

