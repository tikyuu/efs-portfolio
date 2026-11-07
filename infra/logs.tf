resource "aws_cloudwatch_log_group" "writer" {
  name              = "/ecs/efs/writer"
  retention_in_days = 30

  tags = {
    Name = "/ecs/efs/writer"
  }
}

resource "aws_cloudwatch_log_group" "reader" {
  name              = "/ecs/efs/reader"
  retention_in_days = 30

  tags = {
    Name = "/ecs/efs/reader"
  }
}
