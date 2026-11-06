resource "aws_vpc" "efs" {
  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-efs"
  }
}

resource "aws_subnet" "private_1a" {
  vpc_id                  = aws_vpc.efs.id
  cidr_block              = "10.30.10.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-efs-private-1a"
  }
}

resource "aws_subnet" "private_1c" {
  vpc_id                  = aws_vpc.efs.id
  cidr_block              = "10.30.11.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-efs-private-1c"
  }
}
