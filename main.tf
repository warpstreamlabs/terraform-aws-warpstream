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

data "aws_iam_policy_document" "warpstream_s3" {
  statement {
    sid    = "AllowS3"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "${aws_s3_bucket.warpstream.arn}",
      "${aws_s3_bucket.warpstream.arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "agent" {
  name               = "agent_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy" "agent_s3" {
  name   = "agent_s3"
  role   = aws_iam_role.agent.name
  policy = data.aws_iam_policy_document.warpstream_s3.json
}

resource "aws_ecs_cluster" "warpstream" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

data "aws_iam_role" "ecs" {
  name = "ecsTaskExecutionRole"
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
  })
  requires_compatibilities = ["FARGATE"]
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  cpu                = 1024
  memory             = 2048
  network_mode       = "awsvpc"
  execution_role_arn = data.aws_iam_role.ecs.arn
  task_role_arn      = aws_iam_role.agent.arn
}

data "aws_vpc" "default" {
  default = "true"
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_ecs_service" "warpstream_agent" {
  name            = "warpstream-agent"
  cluster         = aws_ecs_cluster.warpstream.id
  task_definition = aws_ecs_task_definition.warpstream_agent.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  # iam_role        = aws_iam_role.foo.arn
  # depends_on      = [aws_iam_role_policy.foo]

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    assign_public_ip = true
  }

  #load_balancer {
  #  target_group_arn = aws_lb_target_group.foo.arn
  #  container_name   = "warpstream-agent"
  #  container_port   = 8080
  #}
}
