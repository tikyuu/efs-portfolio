resource "aws_ecr_repository" "efs" {
  name                 = "ecr-efs"
  image_tag_mutability = "IMMUTABLE"

  tags = {
    Name = "ecr-efs"
  }
}
