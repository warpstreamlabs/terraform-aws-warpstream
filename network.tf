data "aws_vpc" "default" {
  count   = var.vpc_id != null ? 0 : 1
  default = "true"
}

locals {
  vpc = var.vpc_id != null ? var.vpc_id : data.aws_vpc.default[0].id
}

data "aws_subnets" "all" {
  count = length(var.vpc_subnets) > 0 ? 0 : 1
  filter {
    name   = "vpc-id"
    values = [local.vpc]
  }
}

locals {
  subnets = length(var.vpc_subnets) > 0 ? var.vpc_subnets : data.aws_subnets.all[0].ids
}

resource "aws_lb" "warpstream" {
  count              = var.create_lb ? 1 : 0
  name               = "warpstream-lb"
  internal           = false
  load_balancer_type = "network"
  subnets            = local.subnets
}

resource "aws_lb_listener" "warpstream_agent" {
  count             = var.create_lb ? 1 : 0
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
  name        = "warpstream-agent-lb"
  port        = 9092
  protocol    = "TCP"
  vpc_id      = local.vpc
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
