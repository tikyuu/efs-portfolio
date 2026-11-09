# 学習用の厳しい条件：1分間にアプリの5xx応答が1件以上で異常とする。
# TGの役割は更新ごとに入れ替わるため、両方を監視する。
resource "aws_cloudwatch_metric_alarm" "app_target_5xx" {
  alarm_name          = "alarm-efs-app-target-5xx"
  alarm_description   = "Application target 5xx responses: at least one in one minute"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"

  # 通信のないTGなどでデータが欠けても、それだけでは異常としない。
  treat_missing_data = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.efs.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "app_alternate_target_5xx" {
  alarm_name          = "alarm-efs-app-alternate-target-5xx"
  alarm_description   = "Alternate application target 5xx responses: at least one in one minute"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.efs.arn_suffix
    TargetGroup  = aws_lb_target_group.app_alternate.arn_suffix
  }
}
