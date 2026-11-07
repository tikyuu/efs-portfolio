# Interface endpointは各サービスにつき1つ。ENIは1aだけに配置する。
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.efs.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1a.id]
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-efs-ecr-api-1a"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.efs.id
  service_name        = "com.amazonaws.ap-northeast-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1a.id]
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-efs-ecr-dkr-1a"
  }
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.efs.id
  service_name        = "com.amazonaws.ap-northeast-1.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1a.id]
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = true

  tags = {
    Name = "vpce-efs-logs-1a"
  }
}

# 現在、両サブネットはVPCのメインルートテーブルを暗黙に利用する。
# S3 Gateway endpointにはサブネットやSGを指定しない。
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.efs.id
  service_name      = "com.amazonaws.ap-northeast-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_vpc.efs.main_route_table_id]

  tags = {
    Name = "vpce-efs-s3"
  }
}
