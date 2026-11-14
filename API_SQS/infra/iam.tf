# API Gatewayが引き受けるロール。
resource "aws_iam_role" "api_gateway_sqs" {
  name = "role-apigw-reports-sqs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# 通常のキューへの送信だけを許可する。
resource "aws_iam_role_policy" "api_gateway_sqs_send" {
  name = "policy-apigw-reports-sqs-send"
  role = aws_iam_role.api_gateway_sqs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.reports.arn
    }]
  })
}
