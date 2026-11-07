resource "aws_efs_file_system" "efs" {
  encrypted = true

  tags = {
    Name = "efs"
  }
}

resource "aws_efs_mount_target" "private_1a" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.private_1a.id
  security_groups = [aws_security_group.mount.id]
}

resource "aws_efs_mount_target" "private_1c" {
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = aws_subnet.private_1c.id
  security_groups = [aws_security_group.mount.id]
}
