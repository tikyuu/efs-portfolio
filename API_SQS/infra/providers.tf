provider "aws" {
  region = "ap-northeast-1"
}

# 適用先のAWSアカウントIDを参照する。
data "aws_caller_identity" "current" {}
