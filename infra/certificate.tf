resource "aws_acm_certificate" "efs" {
  domain_name       = "efs.tikyuu.click"
  validation_method = "DNS"

  tags = {
    Name = "acm-efs"
  }
}

# ACMが指定する名前と値を、所有確認用のDNSレコードとして登録する。
# 今回の証明書は1ドメインなので、その1件を参照する。
resource "aws_route53_record" "certificate_validation" {
  zone_id = aws_route53_zone.efs.zone_id
  name    = tolist(aws_acm_certificate.efs.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.efs.domain_validation_options)[0].resource_record_type
  records = [tolist(aws_acm_certificate.efs.domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

# ドメイン登録側のネームサーバーを合わせないと、所有確認は完了しない。
resource "aws_acm_certificate_validation" "efs" {
  certificate_arn = aws_acm_certificate.efs.arn

  validation_record_fqdns = [
    aws_route53_record.certificate_validation.fqdn,
  ]
}
