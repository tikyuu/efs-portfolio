resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/efs/app"
  retention_in_days = 30

  tags = {
    Name = "/ecs/efs/app"
  }
}
