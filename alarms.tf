resource "aws_cloudwatch_metric_alarm" "lb_5xx" {
  alarm_name                = "${aws_lb.default.name}-5xx-errors"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "2"
  metric_name               = "HTTPCode_ELB_5XX_Count"
  namespace                 = "AWS/ApplicationELB"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "50"

  dimensions = {
    LoadBalancer = aws_lb.default.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "tg_healthy_hosts" {
  alarm_name                = "${aws_lb_target_group.default.name}-healthy-hosts"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "HealthyHostCount"
  namespace                 = "AWS/ApplicationELB"
  period                    = "60"
  statistic                 = "Maximum"
  threshold                 = "1"

  dimensions = {
    TargetGroup  = aws_lb_target_group.default.arn_suffix
    LoadBalancer = aws_lb.default.arn_suffix
  }
}
