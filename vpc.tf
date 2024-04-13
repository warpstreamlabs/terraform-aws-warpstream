data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    visibility = var.vpc_subnet_visibility_tag
  }
}
