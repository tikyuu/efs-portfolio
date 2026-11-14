# 繰り返し処理できなかった帳票作成依頼を保存するキュー。
resource "aws_sqs_queue" "reports_dlq" {
  name                      = "sqs-reports-dlq"
  message_retention_seconds = 1209600 # 14日
  sqs_managed_sse_enabled   = true
}

# 帳票作成依頼を受け付け、取得回数の上限を超えた依頼はDLQへ移す。
resource "aws_sqs_queue" "reports" {
  name                       = "sqs-reports"
  visibility_timeout_seconds = 180
  message_retention_seconds  = 345600 # 4日
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.reports_dlq.arn
    maxReceiveCount     = 5
  })
}
