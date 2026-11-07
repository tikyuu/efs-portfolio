resource "aws_ecs_cluster" "efs" {
  name = "ecs-efs-cluster"

  tags = {
    Name = "ecs-efs-cluster"
  }
}
