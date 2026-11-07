resource "aws_iam_role" "task_execution" {
  name = "iam-efs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "iam-efs-task-execution-role"
  }
}

# AWSが用意したポリシーで、ECRからのイメージ取得と
# CloudWatch Logsのログストリーム作成・ログ書き込みを許可する。
resource "aws_iam_role_policy_attachment" "task_execution" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
