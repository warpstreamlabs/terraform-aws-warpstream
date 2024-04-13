locals {
  service_name = "warpstream-agent"
}

module "service" {
  source = "terraform-aws-modules/ecs/aws//modules/service"

  name        = local.service_name
  cluster_arn = local.cluster_arn

  desired_count            = 1
  cpu                      = var.cpu * 1024
  memory                   = var.memory * 1024
  force_new_deployment     = true
  requires_compatibilities = ["EC2", "FARGATE"]
  network_mode             = "awsvpc"
  runtime_platform = {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  container_definitions = {
    "agent" = jsondecode(templatefile("${path.module}/container-definitions/agent.json", {
      image      = "public.ecr.aws/warpstream-labs/warpstream_agent:${var.agent_version}",
      bucket_url = "s3://${var.bucket_name}?region=${local.bucket_region}",
      region = local.bucket_region,
      api_key    = var.api_key,
      vc_id      = var.virtual_cluster,
      warpstream_region = var.warpstream_region,
    }))
  }

  iam_role_name = var.agent_role_name
  subnet_ids    = data.aws_subnets.subnets.ids
  tags = merge(local.tags, {
    ServiceName = local.service_name
  })

  load_balancer = var.create_lb ? {
    target_group_arn = aws_lb_target_group.warpstream_agent[0].arn
    container_name   = "warpstream-agent"
    container_port   = 9092
  } : {}
}

