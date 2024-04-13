locals {
  cluster_arn = var.create_cluster ? aws_ecs_cluster.warpstream[0].arn : data.aws_ecs_cluster.warpstream[0].arn
}

data "aws_ecs_cluster" "warpstream" {
  count        = var.create_cluster ? 0 : 1
  cluster_name = var.cluster_name
}

resource "aws_ecs_cluster" "warpstream" {
  count = var.create_cluster ? 1 : 0

  name = var.cluster_name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
