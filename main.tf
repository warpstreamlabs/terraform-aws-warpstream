resource "aws_ecs_cluster" "warpstream" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "warpstream_agent" {
  name = "/ecs/warpstream_agent"
}

resource "aws_ecs_task_definition" "warpstream_agent" {
  family = "warpstream-agent"
  container_definitions = templatefile("${path.module}/container-definitions.json", {
    image      = "public.ecr.aws/warpstream-labs/warpstream_agent:${var.agent_version}",
    bucket_url = "s3://${var.bucket_name}?region=${aws_s3_bucket.warpstream.region}",
    api_key    = var.api_key,
    vc_id      = var.virtual_cluster,
    ap_name    = var.agent_pool_name,
  })
  requires_compatibilities = ["EC2", "FARGATE"]
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  cpu                = var.cpu * 1024
  memory             = var.memory * 1024
  network_mode       = "awsvpc"

  # execution_role_arn = data.aws_iam_role.ecs.arn
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  # task_role_arn      = aws_iam_role.agent.arn
  task_role_arn      = aws_iam_role.ecs_task_iam_role.arn
}

resource "aws_ecs_service" "warpstream_agent" {
  name            = "warpstream-agent"
  cluster         = aws_ecs_cluster.warpstream.id
  task_definition = aws_ecs_task_definition.warpstream_agent.arn
  desired_count   = 1
  launch_type     = "EC2"
  # iam_role        = aws_iam_role.ecs_service_role.arn

  network_configuration {
    subnets          = data.aws_subnets.all.ids
    # assign_public_ip = true
  }

  dynamic "load_balancer" {
    for_each = var.create_lb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.warpstream_agent[0].arn
      container_name   = "warpstream-agent"
      container_port   = 9092
    }
  }

  ordered_placement_strategy {
   type  = "spread"
   field = "attribute:ecs.availability-zone"
  }
  
  ordered_placement_strategy {
   type  = "binpack"
   field = "memory"
  }

  depends_on = [aws_lb_listener.warpstream_agent]

  lifecycle {
    ignore_changes = [desired_count]
  }
}
