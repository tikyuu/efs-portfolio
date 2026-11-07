resource "aws_vpc" "efs" {
  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-efs"
  }
}

# ALB用のパブリックサブネット。
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.efs.id
  cidr_block              = "10.30.0.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-efs-public-1a"
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id                  = aws_vpc.efs.id
  cidr_block              = "10.30.1.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = false

  tags = {
    Name = "subnet-efs-public-1c"
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

resource "aws_internet_gateway" "efs" {
  vpc_id = aws_vpc.efs.id

  tags = {
    Name = "igw-efs"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.efs.id

  tags = {
    Name = "rtb-efs-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.efs.id
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1c" {
  subnet_id      = aws_subnet.public_1c.id
  route_table_id = aws_route_table.public.id
}
