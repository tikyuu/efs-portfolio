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
      image     = "${aws_ecr_repository.efs.repository_url}:v1"
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
