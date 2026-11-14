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

# POST /reports の接続先と使用するロール。送信内容の変換は次に追加する。
resource "aws_api_gateway_integration" "reports_sqs" {
  rest_api_id             = aws_api_gateway_rest_api.reports.id
  resource_id             = aws_api_gateway_resource.reports.id
  http_method             = aws_api_gateway_method.reports_post.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:ap-northeast-1:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.reports.name}"
  credentials             = aws_iam_role.api_gateway_sqs.arn
}
