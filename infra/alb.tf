resource "aws_lb" "efs" {
  name               = "alb-efs"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  security_groups = [aws_security_group.alb.id]
  subnets = [
    aws_subnet.public_1a.id,
    aws_subnet.public_1c.id,
  ]

  # インターネット向けALBの作成前に、VPCへIGWを接続する。
  depends_on = [aws_internet_gateway.efs]

  tags = {
    Name = "alb-efs"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "tg-efs-app"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.efs.id

  health_check {
    path     = "/health"
    protocol = "HTTP"
    port     = "traffic-port"
    matcher  = "200"
  }

  tags = {
    Name = "tg-efs-app"
  }
}
