
#########################################
#    LAMBDA
#########################################

module "slack_listener_lambda" {
  source = "./slack_listener"

  project_name         = var.project_name
  slack_api_token      = var.slack_api_token
  slack_signing_secret = var.slack_signing_secret
  api_gw_role_arn      = aws_iam_role.api_gw.arn

  # slack_listener_api_endpoint_arn = module.api_gateway.slack_listener_api_endpoint_arn

  log_level = var.log_level
}

#########################################
#    API GATEWAY
#########################################

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "api_gw" {
  statement {
    actions   = ["lambda:*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "api_gw" {
  name        = "${var.project_name}-api-gw"
  description = "Policy used by the Ldap Maintenance API Gateway"
  policy      = "${data.aws_iam_policy_document.api_gw.json}"
}

resource "aws_iam_role" "api_gw" {
  name = "${var.project_name}-api-gw"

  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = var.tags
}

resource "aws_iam_policy_attachment" "api_gw" {
  name       = "ldap-maintainer-api-gw"
  roles      = ["${aws_iam_role.api_gw.name}"]
  policy_arn = "${aws_iam_policy.api_gw.arn}"
}

resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-api"
  description = "Lambda Async test"
}

resource "aws_api_gateway_resource" "event_listener" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "event-listener"
}

resource "aws_api_gateway_method" "event_listener_post" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.event_listener.id}"
  http_method   = "POST"
  authorization = "NONE"
}

locals {
  request_template = <<-TEMPLATE
    #set($allParams = $input.params())
    {
    "body-json" : $input.json('$'),
    "params" : {
    #foreach($type in $allParams.keySet())
    #set($params = $allParams.get($type))
    "$type" : {
        #foreach($paramName in $params.keySet())
        "$paramName" : "$util.escapeJavaScript($params.get($paramName))"
            #if($foreach.hasNext),#end
        #end
    }
        #if($foreach.hasNext),#end
    #end
    },
    "stage-variables" : {
      #foreach($key in $stageVariables.keySet())
      "$key" : "$util.escapeJavaScript($stageVariables.get($key))"
          #if($foreach.hasNext),#end
      #end
    }
    }
    TEMPLATE
}

resource "aws_api_gateway_integration" "event_listener" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.event_listener.id}"
  http_method = "${aws_api_gateway_method.event_listener_post.http_method}"
  credentials = "${aws_iam_role.api_gw.arn}"
  type        = "AWS"

  integration_http_method = "POST"
  request_parameters = {
    "integration.request.header.Content-Type"          = "'application/x-www-form-urlencoded'"
    "integration.request.header.X-Amz-Invocation-Type" = "'Event'"
  }

  request_templates = {
    "application/json"                  = local.request_template
    "application/x-www-form-urlencoded" = local.request_template
  }

  uri = module.slack_listener_lambda.function_invoke_arn

  passthrough_behavior = "WHEN_NO_TEMPLATES"
}

resource "aws_lambda_permission" "apigw_lambda" {
  depends_on = [
    aws_api_gateway_integration.event_listener,
    aws_api_gateway_rest_api.api,
    aws_api_gateway_method.event_listener_post,
    aws_api_gateway_resource.event_listener
  ]

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${module.slack_listener_lambda.function_name}"
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/${aws_api_gateway_method.event_listener_post.http_method}${aws_api_gateway_resource.event_listener.path}"
}

resource "aws_api_gateway_method_response" "event_listener_response_200" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.event_listener.id}"
  http_method = "${aws_api_gateway_method.event_listener_post.http_method}"
  response_models = {
    "application/json"                  = "Empty"
    "application/x-www-form-urlencoded" = "Empty"
  }
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "event_listener_response_200" {
  depends_on = [
    "aws_api_gateway_integration.event_listener"
  ]
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.event_listener.id}"
  http_method = "${aws_api_gateway_method.event_listener_post.http_method}"
  status_code = "${aws_api_gateway_method_response.event_listener_response_200.status_code}"
}

# deploy the api
resource "aws_api_gateway_deployment" "respond" {
  depends_on = [
    "aws_api_gateway_integration.event_listener"
  ]
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "respond"
}
