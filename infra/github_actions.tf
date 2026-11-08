# GitHub Actionsが発行するOIDCトークンをAWSで受け付ける設定。
# 利用を許可するリポジトリ・ブランチは、ロールの信頼ポリシーで制限する。
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "oidc-efs-github"
  }
}

resource "aws_iam_role" "github_actions" {
  name = "iam-efs-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            # GitHub APIで確認した、所有者・リポジトリのIDを含む形式。
            "token.actions.githubusercontent.com:sub" = "repo:tikyuu@224914317/efs-portfolio@1448841569:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Name = "iam-efs-github-actions-role"
  }
}

resource "aws_iam_role_policy" "github_actions_ecr_push" {
  name = "iam-efs-github-actions-ecr-push-policy"
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # 認証トークン取得はリポジトリ単位で制限できないため、対象は「*」。
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        # イメージの確認・送信先は、今回のリポジトリだけに限定する。
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Resource = aws_ecr_repository.efs.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions_ecs_deploy" {
  name = "iam-efs-github-actions-ecs-deploy-policy"
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # サービスの取得・更新・安定待ちは、今回のサービスだけに限定する。
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
        ]
        Resource = aws_ecs_service.app.id
      },
      {
        # この読み取り操作はリソース単位の制限に対応していない。
        Effect   = "Allow"
        Action   = "ecs:DescribeTaskDefinition"
        Resource = "*"
      },
      {
        # 新しい版の登録は、今回のタスク定義ファミリーだけに限定する。
        Effect   = "Allow"
        Action   = "ecs:RegisterTaskDefinition"
        Resource = "${aws_ecs_task_definition.app.arn_without_revision}:*"
      },
      {
        # ECSへ渡せるロールと、渡す相手の両方を限定する。
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.task_execution.arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}
