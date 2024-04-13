resource "aws_cloudwatch_log_group" "warpstream_agent" {
  name = var.log_group_name
}
