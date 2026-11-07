variable "alb_allowed_cidr" {
  description = "ALBへのHTTPS接続を許可する送信元IPv4 CIDR。検証用PCのグローバルIP/32などを指定する。"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.alb_allowed_cidr))
    error_message = "有効なIPv4 CIDRを指定してください。"
  }
}
