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

# ブルーグリーン更新時に、もう一方の版のタスクを登録するTG。
resource "aws_lb_target_group" "app_alternate" {
  name        = "tg-efs-app-alternate"
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
    Name = "tg-efs-app-alternate"
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
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# 全パスの転送先をこのルールへ集約し、ブルーグリーンの切り替えに使う。
resource "aws_lb_listener_rule" "app" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.app.arn
        weight = 100
      }

      target_group {
        arn    = aws_lb_target_group.app_alternate.arn
        weight = 0
      }
    }
  }
}
