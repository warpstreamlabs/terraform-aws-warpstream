resource "aws_lb" "warpstream" {
  count              = var.create_lb ? 1 : 0
  name               = var.lb_name
  internal           = false
  load_balancer_type = "network"
  subnets            = data.aws_subnets.subnets.ids
}

resource "aws_lb_listener" "warpstream_agent" {
  count = var.create_lb ? 1 : 0

  load_balancer_arn = aws_lb.warpstream[0].arn
  port              = 9092
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.warpstream_agent[0].arn
  }
}

resource "aws_lb_target_group" "warpstream_agent" {
  count       = var.create_lb ? 1 : 0
  name        = var.lb_name
  port        = 9092
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 60
    timeout             = 30
    port                = 8080
    protocol            = "HTTP"
    path                = "/v1/status"
    matcher             = 200
  }
}
