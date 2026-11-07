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

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.efs.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"

  # 証明書の発行が完了してから、リスナーを作成する。
  certificate_arn = aws_acm_certificate_validation.efs.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
