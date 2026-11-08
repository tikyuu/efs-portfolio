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

# ECS自身が、ブルーグリーン更新時にALBの転送設定を操作するためのロール。
resource "aws_iam_role" "ecs_load_balancer" {
  name = "iam-efs-ecs-load-balancer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "iam-efs-ecs-load-balancer-role"
  }
}

# AWSが用意した、ターゲットの登録・解除、転送設定の確認・変更用ポリシー。
resource "aws_iam_role_policy_attachment" "ecs_load_balancer" {
  role       = aws_iam_role.ecs_load_balancer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSInfrastructureRolePolicyForLoadBalancers"
}
