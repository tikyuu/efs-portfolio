resource "aws_ecs_cluster" "efs" {
  name = "ecs-efs-cluster"

  tags = {
    Name = "ecs-efs-cluster"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "ecs-efs-app-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn

  volume {
    name = "efs-shared"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.efs.id
      root_directory     = "/"
      transit_encryption = "ENABLED"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "efs-app"
      image     = "${aws_ecr_repository.efs.repository_url}:${var.image_tag}"
      essential = true

      mountPoints = [
        {
          sourceVolume  = "efs-shared"
          containerPath = "/mnt/shared"
          readOnly      = false
        }
      ]

      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = "ap-northeast-1"
          awslogs-stream-prefix = "app"
        }
      }
    }
  ])

  tags = {
    Name = "ecs-efs-app-task"
  }
}

resource "aws_ecs_service" "app" {
  name             = "ecs-efs-app-service"
  cluster          = aws_ecs_cluster.efs.id
  task_definition  = aws_ecs_task_definition.app.arn
  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  desired_count    = 2

  deployment_configuration {
    strategy             = "BLUE_GREEN"
    bake_time_in_minutes = 5
  }

  # タスクの配置が偏った場合、AZ間で再調整する。
  availability_zone_rebalancing     = "ENABLED"
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets = [
      aws_subnet.private_1a.id,
      aws_subnet.private_1c.id,
    ]
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "efs-app"
    container_port   = 8000

    advanced_configuration {
      alternate_target_group_arn = aws_lb_target_group.app_alternate.arn
      production_listener_rule   = aws_lb_listener_rule.app.arn
      role_arn                   = aws_iam_role.ecs_load_balancer.arn
    }
  }

  # 作成後のタスク定義更新はGitHub Actions、TGの切り替えはECSに任せる。
  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }

  # タスク起動に必要な入口・通信経路・権限の作成を待つ。
  depends_on = [
    aws_lb_listener_rule.app,
    aws_efs_mount_target.private_1a,
    aws_efs_mount_target.private_1c,
    aws_iam_role_policy_attachment.task_execution,
    aws_iam_role_policy_attachment.ecs_load_balancer,
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr,
    aws_vpc_endpoint.logs,
    aws_vpc_endpoint.s3,
  ]

  tags = {
    Name = "ecs-efs-app-service"
  }
}
