locals {
  az_count = var.availability_zones
}

## Create VPC with a CIDR block that has enough capacity for the amount of DNS names you need
resource "aws_vpc" "default" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

## Create Internet Gateway for egress/ingress connections to resources in the public subnets
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
}

## List all AZ available in the region
data "aws_availability_zones" "available" {}

## Public Subnets (one public subnet per AZ)
resource "aws_subnet" "public" {
  count                   = local.az_count
  cidr_block              = cidrsubnet(aws_vpc.default.cidr_block, 8, local.az_count + count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = aws_vpc.default.id
  map_public_ip_on_launch = true
}

## Route Table with egress route to the internet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }
}

## Associate Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

## Make our Route Table the main Route Table
resource "aws_main_route_table_association" "public_main" {
  vpc_id         = aws_vpc.default.id
  route_table_id = aws_route_table.public.id
}

## Creates one Elastic IP per AZ (one for each NAT Gateway in each AZ)
resource "aws_eip" "nat_gateway" {
  count  = local.az_count
  domain = "vpc"
}

## Creates one NAT Gateway per AZ
resource "aws_nat_gateway" "nat_gateway" {
  count         = local.az_count
  subnet_id     = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat_gateway[count.index].id
}

## Private Subnets (one private subnet per AZ)
resource "aws_subnet" "private" {
  count             = local.az_count
  cidr_block        = cidrsubnet(aws_vpc.default.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.default.id
}

## Route to the internet using the NAT Gateway
resource "aws_route_table" "private" {
  count  = local.az_count
  vpc_id = aws_vpc.default.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[count.index].id
  }
}

## Associate Route Table with Private Subnets
resource "aws_route_table_association" "private" {
  count          = local.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

## SG for ECS Container Instances
resource "aws_security_group" "ecs_container_instance" {
  name        = "warpstream_ECS_Task_SecurityGroup"
  description = "Security group for ECS task running on Fargate"
  vpc_id      = aws_vpc.default.id

  ingress {
    description     = "Allow ingress traffic from ALB on HTTP only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all egress traffic"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## SG for ALB
resource "aws_security_group" "alb" {
  name        = "warpstream_ALB_SecurityGroup"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.default.id

  egress {
    description = "Allow all egress traffic"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow public ingress traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## Application Load Balancer in public subnets
resource "aws_lb" "alb" {
  name               = "warpstream-ALB"
  load_balancer_type = "application"
  subnets            = aws_subnet.public.*.id
  security_groups    = [aws_security_group.alb.id]
}

## Default HTTP listener
resource "aws_lb_listener" "alb_default_listener_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_target_group.arn
  }
}

## Target Group for our service
resource "aws_lb_target_group" "service_target_group" {
  name                 = "warpstream-tg"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = aws_vpc.default.id
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
