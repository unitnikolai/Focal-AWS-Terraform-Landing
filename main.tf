#Cognito user pool

resource "aws_cognito_user_pool" "main" {
    name = "focal-user-pool"

    username_attributes = ["email"]
    auto_verified_attributes = ["email"]
    
    mfa_configuration = "OFF"

    password_policy {
        minimum_length = 12
        require_uppercase = true
        require_lowercase = true
        require_symbols = true
        require_numbers = true
    }

    account_recovery_setting{
        recovery_mechanism {
            name = "verified_email"
            priority = 1
        }
    }

    # Security settings for JWT token handling
    user_attribute_update_settings {
        attributes_require_verification_before_update = ["email"]
    }

    schema {
        name                     = "email"
        attribute_data_type      = "String"
        required                 = true
        mutable                  = true
    }
}

#Cognito domain (for sso redirects)

resource "aws_cognito_user_pool_domain" "main"{
    domain = "focal-auth-portal"
    user_pool_id = aws_cognito_user_pool.main.id
}

#Google identity

# resource "aws_cognito_identity_provider" "google" {
#     user_pool_id = aws_cognito_user_pool.main.id
#     provider_name = "Google"
#     provider_type = "Google"

#     provider_details = {
#         authorize_scopes = "email openid profile"
#         client_id        = "YOUR_GOOGLE_CLIENT_ID"
#         client_secret    = "YOUR_GOOGLE_CLIENT_SECRET"
#         attributes_url   = "https://people.googleapis.com/v1/people/me?personFields="
#         attributes_url_add_attributes = "true"
#         authorize_url    = "https://accounts.google.com/o/oauth2/v2/auth"
#         token_url        = "https://www.googleapis.com/oauth2/v4/token"
#         token_request_method = "POST"
#         oidc_issuer      = "https://accounts.google.com"
#   }
#   attribute_mapping = {
#     email = "email"
#     username = "sub"
#   }
# }

resource "aws_cognito_user_pool_client" "client"{
    name = "focal-client"
    generate_secret = false
    explicit_auth_flows = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
    user_pool_id = aws_cognito_user_pool.main.id
    allowed_oauth_flows_user_pool_client = true
    allowed_oauth_flows = ["code"]
    allowed_oauth_scopes = ["email", "openid", "profile"]
    supported_identity_providers = ["COGNITO"]
    # supported_identity_providers = ["COGNITO", "Google"]

    # JWT Token configuration for secure cookie storage
    access_token_validity = 1
    id_token_validity = 1
    refresh_token_validity = 30
    token_validity_units {
        access_token  = "hours"
        id_token      = "hours"
        refresh_token = "days"
    }

    # Secure callback and logout URLs (use HTTPS in production)
    callback_urls = ["http://localhost:3000/", "https://main.deu6lm3uucumx.amplifyapp.com/"]
    logout_urls = ["http://localhost:3000/", "https://main.deu6lm3uucumx.amplifyapp.com/"]

    # Cookie settings for secure token storage
    prevent_user_existence_errors = "ENABLED"
}

#Keys
resource "aws_kms_key" "rds_dbs_key"{
    description = "KMS Key for Serverless SQL"
    deletion_window_in_days = 10
    enable_key_rotation = true
}

resource "aws_kms_alias" "rds_key"{
    name = "alias/app-db-key"
    target_key_id = aws_kms_key.rds_dbs_key.key_id
}

#VPC: app-vpc (10.0.0.0/16)
#│
#├─ Private Subnet 1 (10.0.0.0/20) → AZ = writer_az (us-east-1a)
#│
#└─ Private Subnet 2 (10.0.16.0/20) → AZ = reader_az (us-east-1b)

variable "writer_az" {
  default = "us-east-1a"
}

variable "reader_az" {
  default = "us-east-1b"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "app_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = "app-vpc" }
}

resource "aws_subnet" "private" {
  count = 2
  vpc_id = aws_vpc.app_vpc.id
  cidr_block = cidrsubnet(aws_vpc.app_vpc.cidr_block, 4, count.index)
  availability_zone = count.index == 0 ? var.writer_az : var.reader_az
  map_public_ip_on_launch = false
  tags = { Name = "private-subnet-${count.index + 1}" }
}

locals {
  private_subnet_ids = aws_subnet.private[*].id
}

resource "aws_security_group" "lambda_sg" {
    name = "lambda-sg"
    vpc_id = aws_vpc.app_vpc.id

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = { Name = "Lambda SG"}
}



#App SG Lambda group
#│
#└─ RDS SG: rds-postgres-sg 
#   - Ingress: TCP 5432 from App SG
#   - Egress: All (0.0.0.0/0)

#VPC Sec Group
resource "aws_security_group" "db_sg"{
    name = "rds-postgres-sg"
    description = "Postgres access from app"
    vpc_id = aws_vpc.app_vpc.id

    ingress {
        description = "Postgres from app"
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        security_groups = [aws_security_group.lambda_sg.id]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "rds-postgres-sg"
    }
}

resource "aws_db_subnet_group" "db_subnets"{
    name = "rds-db-subnet-group"
    subnet_ids = local.private_subnet_ids

    tags = {
        Name = "RDS Private Subnets"
    }
}

resource "aws_db_instance" "writer" {
    identifier = "app-db-writer"
    engine = "postgres"
    engine_version = "15"
    instance_class = "db.t4g.micro"
    allocated_storage = 20
    storage_type = "gp3"
    db_name = "focal_db_1"
    username = var.db_username
    password = var.db_password
    
    availability_zone = var.writer_az
    db_subnet_group_name = aws_db_subnet_group.db_subnets.name
    vpc_security_group_ids = [aws_security_group.db_sg.id]
    publicly_accessible    = false

    backup_retention_period = 7
    skip_final_snapshot     = true

    storage_encrypted = true
    kms_key_id        = aws_kms_key.rds_dbs_key.arn

    multi_az                  = false
    performance_insights_enabled = false
    deletion_protection        = false

    tags = {
        Name = "App PostgreSQL Writer"
    }
}

resource "aws_db_instance" "reader" {
  identifier             = "app-db-reader"
  engine                 = "postgres"
  instance_class         = "db.t4g.micro"
  replicate_source_db    = aws_db_instance.writer.id
  
  availability_zone = var.reader_az
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds_dbs_key.arn

  tags = {
    Name = "App PostgreSQL Reader"
  }
}
