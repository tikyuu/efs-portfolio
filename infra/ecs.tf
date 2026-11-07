resource "aws_ecs_cluster" "efs" {
  name = "ecs-efs-cluster"

  tags = {
    Name = "ecs-efs-cluster"
  }
}

resource "aws_ecs_task_definition" "writer" {
  family                   = "ecs-efs-writer-task"
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
      name      = "efs-writer"
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
          awslogs-group         = aws_cloudwatch_log_group.writer.name
          awslogs-region        = "ap-northeast-1"
          awslogs-stream-prefix = "writer"
        }
      }
    }
  ])

  tags = {
    Name = "ecs-efs-writer-task"
  }
}

resource "aws_ecs_task_definition" "reader" {
  family                   = "ecs-efs-reader-task"
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
      name      = "efs-reader"
      image     = "${aws_ecr_repository.efs.repository_url}:v1"
      essential = true

      mountPoints = [
        {
          sourceVolume  = "efs-shared"
          containerPath = "/mnt/shared"
          readOnly      = true
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
          awslogs-group         = aws_cloudwatch_log_group.reader.name
          awslogs-region        = "ap-northeast-1"
          awslogs-stream-prefix = "reader"
        }
      }
    }
  ])

  tags = {
    Name = "ecs-efs-reader-task"
  }
}
