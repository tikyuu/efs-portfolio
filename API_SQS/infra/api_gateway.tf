# 帳票作成依頼を受け付けるREST API本体。
resource "aws_api_gateway_rest_api" "reports" {
  name = "apigw-reports"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# APIのルート直下に /reports のパスを定義する。
resource "aws_api_gateway_resource" "reports" {
  rest_api_id = aws_api_gateway_rest_api.reports.id
  parent_id   = aws_api_gateway_rest_api.reports.root_resource_id
  path_part   = "reports"
}

# /reports へのPOSTを、IAM認証で受け付ける。
resource "aws_api_gateway_method" "reports_post" {
  rest_api_id   = aws_api_gateway_rest_api.reports.id
  resource_id   = aws_api_gateway_resource.reports.id
  http_method   = "POST"
  authorization = "AWS_IAM"
}

# POST /reports をSQSへ接続し、受け取ったJSONを送信用の形式へ変換する。
resource "aws_api_gateway_integration" "reports_sqs" {
  rest_api_id             = aws_api_gateway_rest_api.reports.id
  resource_id             = aws_api_gateway_resource.reports.id
  http_method             = aws_api_gateway_method.reports_post.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:ap-northeast-1:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.reports.name}"
  credentials             = aws_iam_role.api_gateway_sqs.arn

  # SQSへ送る本文の形式を指定する。
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  # 受け取ったJSONを、SQSに登録するメッセージ本文にする。
  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)"
  }
}

# 依頼の受付成功を表す応答。
resource "aws_api_gateway_method_response" "reports_accepted" {
  rest_api_id = aws_api_gateway_rest_api.reports.id
  resource_id = aws_api_gateway_resource.reports.id
  http_method = aws_api_gateway_method.reports_post.http_method
  status_code = "202"
}

# SQSが登録成功（200）を返した場合だけ、呼び出し元へ202を返す。
resource "aws_api_gateway_integration_response" "reports_accepted" {
  rest_api_id       = aws_api_gateway_rest_api.reports.id
  resource_id       = aws_api_gateway_resource.reports.id
  http_method       = aws_api_gateway_integration.reports_sqs.http_method
  status_code       = aws_api_gateway_method_response.reports_accepted.status_code
  selection_pattern = "200"
}
