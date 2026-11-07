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

  container_definitions = jsonencode([
    {
      name      = "efs-writer"
      image     = "${aws_ecr_repository.efs.repository_url}:v1"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.efs.name
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
