locals {
  service_name = "warpstream_agent_${var.namespace_suffix}"
}

module "ecs_service" {
  source = "terraform-aws-modules/ecs/aws//modules/service"

  name        = local.service_name
  cluster_arn     = local.cluster_arn

  desired_count            = 1
  cpu                      = var.cpu * 1024
  memory                   = var.memory * 1024
  force_new_deployment     = true
  requires_compatibilities = ["EC2"]
  
  launch_type              = "EC2"
  network_mode             = "awsvpc"
  runtime_platform = {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  container_definitions = {
    "warpstream-agent" = {
      cpu       = var.cpu * 512
      memory    = var.memory * 1024
      essential = true
      image     = "public.ecr.aws/warpstream-labs/warpstream_agent:${var.agent_version}"
      port_mappings = [
        {
          name          = "warpstream-agent-9092"
          containerPort = 9092
          hostPort      = 9092
          protocol      = "tcp"
          app_protocol  = "http"
        },
        {
          name          = "warpstream-agent-8080"
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
          app_protocol  = "http"
        }
      ]
      log_configuration = {
        log_driver = "awslogs"
        options = {
          "awslogs-create-group" : "true"
          "awslogs-group" : aws_cloudwatch_log_group.warpstream_agent.name
          "awslogs-region" : local.bucket_region
          "awslogs-stream-prefix" : "ecs"
        }
      }
      command = [
        "agent"
      ]
      memory_reservation = 100
      environment = [
        {
          name  = "WARPSTREAM_API_KEY"
          value = var.api_key
        },
        {
          name  = "WARPSTREAM_BUCKET_URL"
          value = "s3://${var.bucket_name}?region=${local.bucket_region}"
        },
        {
          name  = "WARPSTREAM_DEFAULT_VIRTUAL_CLUSTER_ID"
          value = var.virtual_cluster
        },
        {
          name  = "WARPSTREAM_REGION"
          value = var.warpstream_region
        }
      ]
    }

    #jsondecode(templatefile("${path.module}/container-definitions/agent.json", {
    #image      = "public.ecr.aws/warpstream-labs/warpstream_agent:${var.agent_version}",
    #bucket_url = "s3://${var.bucket_name}?region=${local.bucket_region}",
    #region = local.bucket_region,
    #api_key    = var.api_key,
    #vc_id      = var.virtual_cluster,
    #warpstream_region = var.warpstream_region,
    #}))
  }

  create_tasks_iam_role = false
  tasks_iam_role_arn    = local.agent_role_arn

  subnet_ids = local.subnet_ids
  security_group_rules = {
    ingress_http = {
      type        = "ingress"
      from_port   = 9092
      to_port     = 9092
      protocol    = "tcp"
      description = "Service port"
      #source_security_group_id = module.ingress.security_group_id
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = merge(local.tags, {
    ServiceName = local.service_name
  })

  load_balancer = var.create_lb ? {
    target_group_arn = aws_lb_target_group.warpstream_agent[0].arn
    container_name   = "warpstream-agent"
    container_port   = 9092
  } : {}
}
