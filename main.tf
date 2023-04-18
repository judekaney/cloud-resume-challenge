terraform {
    backend "remote" {
        organization = "judekaney"
        workspaces {
            name = "resume-gitactions"
        }
    }
}


provider "aws" {
    region = "us-east-1"
}

resource "aws_s3_bucket_website_configuration" "judekaney_host_bucket" {
    bucket = "judekaney.com"

    index_document {
        suffix = "index.html"
    }   
}

resource "aws_s3_object" "indexhtml" {
  bucket = aws_s3_bucket_website_configuration.judekaney_host_bucket.id
  key = "index.html"
  source = "S3/index.html"
  content_type = "text/html"
}

resource "aws_s3_object" "visitor-countjs" {
  bucket = aws_s3_bucket_website_configuration.judekaney_host_bucket.id
  key = "visitor-count.js"
  source = "S3/visitor-count.js"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
    origin {
        domain_name = "${data.aws_s3_bucket.judekaney_host_bucket.website_endpoint}"
        origin_id = "S3-${data.aws_s3_bucket.judekaney_host_bucket.id}"
        custom_origin_config {
            origin_ssl_protocols = ["TLSv1.2"]
            http_port = "80"
            https_port = "443"
            origin_protocol_policy = "http-only"
            
        }
    }

    aliases = ["judekaney.com", "www.judekaney.com"]

    http_version = "http2and3"
    is_ipv6_enabled = true

    default_cache_behavior {
        compress = true
        allowed_methods = ["GET", "HEAD"] 
        cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
        target_origin_id = "S3-${data.aws_s3_bucket.judekaney_host_bucket.id}"
        cached_methods = ["GET", "HEAD"]
        origin_request_policy_id = "acba4595-bd28-49b8-b9fe-13317c0390fa"
        viewer_protocol_policy = "redirect-to-https"
        

    }

    viewer_certificate {
        acm_certificate_arn = "arn:aws:acm:us-east-1:339828646418:certificate/4160215d-3cea-41e7-bd0d-6d44b12c4262"
        minimum_protocol_version = "TLSv1.2_2021"
        ssl_support_method = "sni-only"
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
    name = "visitor-count"
    read_capacity = 1
    write_capacity = 1
}

resource "aws_api_gateway_rest_api" "judekaneycomAPI" {
  name        = "judekaney.comAPI"
  description = "Invokes python lambda function that updates total visitor count in dynamodb and returns the total."
}

resource "aws_api_gateway_resource" "visitorget" {
  rest_api_id = "7pm15e6gfa"
  parent_id = "nje1t8lb98"
  path_part = "visitorget"
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
  content_handling = "CONVERT_TO_TEXT"
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
    uri = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:339828646418:function:update-return-visitor-count/invocations"
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = data.aws_api_gateway_rest_api.judekaneycomAPI.id
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.judekaneycomAPI.id
  stage_name    = "prod"
  cache_cluster_size = "0.5"
  tags = {}
}

resource "aws_lambda_function" "lambda" {
    function_name = "update-return-visitor-count"
    role = "arn:aws:iam::339828646418:role/update-return-visitor-count-role"
    filename = "lambda/lambda.py"
    runtime = "python3.9"
    handler = "lambda_function.lambda_handler"
    environment {
            variables = {
             "PARTITION_KEY" = "website"
             "TABLE_NAME"    = "visitor-count"
             "VIEW_COUNT"    = "visitors"
             "WEBSITE_NAME"  = "judekaney.com"
            }
    }
}

data "aws_s3_bucket" "judekaney_host_bucket" {
  bucket = "judekaney.com"
}

data "aws_api_gateway_rest_api" "judekaneycomAPI" {
    name = "judekaney.comAPI"
}

data "aws_api_gateway_resource" "visitorget" {
  rest_api_id = data.aws_api_gateway_rest_api.judekaneycomAPI.id
  path        = "/visitorget"
}

