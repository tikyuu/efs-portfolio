resource "aws_route53_zone" "efs" {
  name = "tikyuu.click"

  tags = {
    Name = "zone-efs"
  }
}

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.efs.zone_id
  name    = "efs.tikyuu.click"
  type    = "A"

  alias {
    name                   = aws_lb.efs.dns_name
    zone_id                = aws_lb.efs.zone_id
    evaluate_target_health = true
  }
}
