resource "aws_cloudwatch_log_group" "efs" {
  name              = "/ecs/efs"
  retention_in_days = 30

  tags = {
    Name = "/ecs/efs"
  }
}
