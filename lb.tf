## SG for ALB
resource "aws_security_group" "alb" {
  name        = "warpstream_ALB_SecurityGroup"
  description = "Security group for ALB"
  vpc_id      = local.vpc_id

  egress {
    description = "Allow all egress traffic"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow public HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow public HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## SG for NLB
resource "aws_security_group" "nlb" {
  name        = "warpstream_NLB_SecurityGroup"
  description = "Security group for NLB"
  vpc_id      = local.vpc_id

  egress {
    description = "Allow all egress traffic"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow public TLS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


## Network Load Balancer in public subnets
resource "aws_lb" "nlb" {
  name               = "warpstream-NLB"
  load_balancer_type = "network"
  subnets            = aws_subnet.public.*.id
  security_groups    = [aws_security_group.nlb.id]
}

## Application Load Balancer in public subnets
resource "aws_lb" "alb" {
  name               = "warpstream-ALB"
  load_balancer_type = "application"
  subnets            = aws_subnet.public.*.id
  security_groups    = [aws_security_group.alb.id]
}

## Default HTTP listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_http.arn
  }
}

## Target Group for our service
resource "aws_lb_target_group" "service_http" {
  name                 = "warpstream-http"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = local.vpc_id
  deregistration_delay = 5
  target_type          = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 60
    matcher             = 200
    path                = "/v1/status"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 30
  }

  depends_on = [aws_lb.alb]
}

## Target Group for our service
resource "aws_lb_target_group" "service_kafka" {
  name                 = "warpstream-kafka"
  port                 = 9092
  protocol             = "TCP"
  vpc_id               = local.vpc_id
  deregistration_delay = 5
  target_type          = "ip"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 60
    matcher             = 200
    path                = "/v1/status"
    port                = 8080
    protocol            = "HTTP"
    timeout             = 30
  }

  depends_on = [aws_lb.nlb]
}
