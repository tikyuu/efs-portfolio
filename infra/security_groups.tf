# SG本体と許可ルールを分け、SG同士の相互参照による循環を避ける。
resource "aws_security_group" "task" {
  name        = "efs-task"
  description = "EFS portfolio Fargate tasks"
  vpc_id      = aws_vpc.efs.id

  tags = {
    Name = "sg-efs-task"
  }
}

resource "aws_security_group" "mount" {
  name        = "efs-mount"
  description = "EFS mount targets"
  vpc_id      = aws_vpc.efs.id

  tags = {
    Name = "sg-efs-mount"
  }
}

resource "aws_security_group" "endpoint" {
  name        = "efs-endpoint"
  description = "ECR and CloudWatch Logs interface endpoints"
  vpc_id      = aws_vpc.efs.id

  tags = {
    Name = "sg-efs-endpoint"
  }
}

# タスクからEFSへのNFS通信を、送信側と受信側で許可する。
resource "aws_vpc_security_group_egress_rule" "task_to_mount" {
  security_group_id            = aws_security_group.task.id
  referenced_security_group_id = aws_security_group.mount.id
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  description                  = "NFS to EFS mount targets"
}

resource "aws_vpc_security_group_ingress_rule" "mount_from_task" {
  security_group_id            = aws_security_group.mount.id
  referenced_security_group_id = aws_security_group.task.id
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  description                  = "NFS from Fargate tasks"
}

# ECR API・DKRとLogsのInterface endpointで共用するSG。
resource "aws_vpc_security_group_egress_rule" "task_to_endpoint" {
  security_group_id            = aws_security_group.task.id
  referenced_security_group_id = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS to interface endpoints"
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_task" {
  security_group_id            = aws_security_group.endpoint.id
  referenced_security_group_id = aws_security_group.task.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from Fargate tasks"
}

# AWSが管理する東京リージョンのS3宛先一覧を参照する。
# Gateway endpoint自体にはSGを付けない。経路の作成は別工程。
data "aws_prefix_list" "s3" {
  name = "com.amazonaws.ap-northeast-1.s3"
}

resource "aws_vpc_security_group_egress_rule" "task_to_s3" {
  security_group_id = aws_security_group.task.id
  prefix_list_id    = data.aws_prefix_list.s3.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to regional S3 for ECR image layers"
}
