terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = " 4.62.0"
    }
    github = {
      source  = "integrations/github"
      version = "5.12.0"
    }
  }
  backend "remote" {
    organization = "judekaney"
    workspaces {
      name = "resume-gitactions"
    }
  }
}

variable "GIT_TOKEN" {
  type = string
}

provider "aws" {
  region = "us-east-1"
}

provider "github" {
  token = var.GIT_TOKEN
}

resource "aws_s3_bucket_website_configuration" "judekaney_host_bucket" {
  bucket = "judekaney.com"

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_object" "indexhtml" {
  bucket       = aws_s3_bucket_website_configuration.judekaney_host_bucket.id
  key          = "index.html"
  content      = data.github_repository_file.index.content
  content_type = "text/html"
}

resource "aws_s3_object" "visitor-countjs" {
  bucket = aws_s3_bucket_website_configuration.judekaney_host_bucket.id
  key    = "visitor-count.js"
  content = data.github_repository_file.visitorcount.content
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = data.aws_s3_bucket.judekaney_host_bucket.website_endpoint
    origin_id   = "S3-${data.aws_s3_bucket.judekaney_host_bucket.id}"
    custom_origin_config {
      origin_ssl_protocols   = ["TLSv1.2"]
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"

    }
  }

  aliases = ["judekaney.com", "www.judekaney.com"]

  http_version    = "http2and3"
  is_ipv6_enabled = true

  default_cache_behavior {
    compress                 = true
    allowed_methods          = ["GET", "HEAD"]
    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    target_origin_id         = "S3-${data.aws_s3_bucket.judekaney_host_bucket.id}"
    cached_methods           = ["GET", "HEAD"]
    origin_request_policy_id = "acba4595-bd28-49b8-b9fe-13317c0390fa"
    viewer_protocol_policy   = "redirect-to-https"


  }

  viewer_certificate {
    acm_certificate_arn      = "arn:aws:acm:us-east-1:339828646418:certificate/4160215d-3cea-41e7-bd0d-6d44b12c4262"
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  enabled = true

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

resource "aws_route53_hosted_zone_dnssec" "judekaneycom" {
  hosted_zone_id = "Z0430325TQEXQ3ACFAQM"
  signing_status = "NOT_SIGNING"
}

resource "aws_dynamodb_table" "visitor-count" {
  name           = "visitor-count"
  read_capacity  = 1
  write_capacity = 1
  hash_key = "website"
  
  attribute {
    name = "website"
    type = "S"
  }
}

resource "aws_api_gateway_rest_api" "judekaneycomAPI" {
  name        = "judekaney.comAPI"
  description = "Invokes python lambda function that updates total visitor count in dynamodb and returns the total."
}

resource "aws_api_gateway_resource" "visitorget" {
  rest_api_id = data.aws_api_gateway_rest_api.judekaneycomAPI.id
  parent_id   = data.aws_api_gateway_rest_api.judekaneycomAPI.root_resource_id
  path_part   = "visitorget"
}

resource "aws_api_gateway_method" "method" {
  rest_api_id   = data.aws_api_gateway_rest_api.judekaneycomAPI.id
  resource_id   = data.aws_api_gateway_resource.visitorget.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = data.aws_api_gateway_rest_api.judekaneycomAPI.id
  resource_id             = data.aws_api_gateway_resource.visitorget.id
  http_method             = aws_api_gateway_method.method.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  content_handling        = "CONVERT_TO_TEXT"
  request_templates = {
    "application/json" = <<-EOT
                {
                  "method": "$context.httpMethod",
                  "body" : $input.json('$'),
                  "headers": {
                    "Visited": "$input.params().header.get('visited')"
                  }
                }
            EOT
  }
  uri = aws_lambda_function.lambda.invoke_arn
}

resource "aws_api_gateway_method_response" "methodresponse" {
  rest_api_id             = data.aws_api_gateway_rest_api.judekaneycomAPI.id
  resource_id             = data.aws_api_gateway_resource.visitorget.id
  http_method             = aws_api_gateway_method.method.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "response" {
  rest_api_id             = data.aws_api_gateway_rest_api.judekaneycomAPI.id
  resource_id             = data.aws_api_gateway_resource.visitorget.id
  http_method             = aws_api_gateway_method.method.http_method
  status_code = "200"
  
  content_handling        = "CONVERT_TO_TEXT"
  request_templates = {
    "application/json" = <<-EOT
                {
                  "method": "$context.httpMethod",
                  "body" : $input.json('$'),
                  "headers": {
                    "Visited": "$input.params().header.get('visited')"
                  }
                }
            EOT
  }
}

resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [aws_api_gateway_integration.integration]
  rest_api_id = data.aws_api_gateway_rest_api.judekaneycomAPI.id
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id      = aws_api_gateway_deployment.deployment.id
  rest_api_id        = aws_api_gateway_rest_api.judekaneycomAPI.id
  stage_name         = "prod"
  cache_cluster_size = "0.5"
  tags               = {}
}

resource "aws_lambda_function" "lambda" {
  function_name = "update-return-visitor-count"
  role          = "arn:aws:iam::339828646418:role/update-return-visitor-count-role"
  filename      = "lambda.zip"
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  environment {
    variables = {
      "PARTITION_KEY" = "website"
      "TABLE_NAME"    = "visitor-count"
      "VIEW_COUNT"    = "visitors"
      "WEBSITE_NAME"  = "judekaney.com"
    }
  }
}

data "github_repository_file" "index" {
  repository = "resume-gitactions"
  file       = "S3-objects/index.html"
}

data "github_repository_file" "visitorcount" {
  repository = "resume-gitactions"
  file       = "S3-objects/visitor-count.js"
}

data "github_repository_file" "lambdafile" {
  repository = "resume-gitactions"
  file = "lambda/lambda.py"
}

data "archive_file" "lambda" {
  depends_on = [data.github_repository_file.lambdafile]
  type = "zip"
  source_content = data.github_repository_file.lambdafile.content
  source_content_filename = "lambda.py"
  output_path = "lambda.zip"
}

data "aws_s3_bucket" "judekaney_host_bucket" {
  bucket = "judekaney.com"
}

data "aws_api_gateway_rest_api" "judekaneycomAPI" {
  depends_on = [aws_api_gateway_rest_api.judekaneycomAPI]
  name = "judekaney.comAPI"
}

data "aws_api_gateway_resource" "visitorget" {
  depends_on = [aws_api_gateway_resource.visitorget]
  rest_api_id = data.aws_api_gateway_rest_api.judekaneycomAPI.id
  path        = "/visitorget"
}
