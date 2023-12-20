resource "aws_s3_bucket" "warpstream" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = "production"
  }
}

resource "aws_s3_bucket_metric" "warpstream" {
  bucket = aws_s3_bucket.warpstream.id
  name   = "EntireBucket"
}

resource "aws_s3_bucket_lifecycle_configuration" "warpstream" {
  bucket = aws_s3_bucket.warpstream.id

  # Automatically cancel all multi-part uploads after 7d so we don't accumulate an infinite
  # number of partial uploads.
  rule {
    id     = "7d multi-part"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # No other lifecycle policy. The WarpStream Agent will automatically clean up and
  # deleted expired files.
}

resource "aws_ecs_cluster" "warpstream" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
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
  execution_role_arn = data.aws_iam_role.ecs.arn
  task_role_arn      = aws_iam_role.agent.arn
}

resource "aws_ecs_service" "warpstream_agent" {
  name            = "warpstream-agent"
  cluster         = aws_ecs_cluster.warpstream.id
  task_definition = aws_ecs_task_definition.warpstream_agent.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.subnets
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.warpstream_agent.arn
    container_name   = "warpstream-agent"
    container_port   = 9092
  }

  depends_on = [aws_lb_listener.warpstream_agent]
}
