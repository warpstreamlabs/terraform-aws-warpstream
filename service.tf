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
  requires_compatibilities = ["EC2"]
  capacity_provider_strategy = {
    # On-demand instances
    ex_1 = {
      capacity_provider = aws_ecs_capacity_provider.ecs_asg_capacity_provider.name
      weight            = 1
      base              = 1
    }
  }
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

resource "aws_autoscaling_group" "ecs_asg" {
  name_prefix = "asg_${var.namespace_suffix}"
  max_size = 10
  min_size = 1
  health_check_type         = "EC2"

  vpc_zone_identifier = var.subnet_ids
  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = aws_launch_template.ecs_launch_template.latest_version
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "asg"
    propagate_at_launch = true
  }

  protect_from_scale_in = true
}

module "ecs_cluster" {
  source = "terraform-aws-modules/ecs/aws//modules/cluster"

  cluster_name = "ecs_ec2_${var.namespace_suffix}"

  # Capacity provider - autoscaling groups
  default_capacity_provider_use_fargate = false
  autoscaling_capacity_providers = {
    one = {
      auto_scaling_group_arn         = aws_autoscaling_group.ecs_asg.arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 10
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 99
      }

      default_capacity_provider_strategy = {
        weight = 199
        base   = 1
      }
    }
  }

  tags = local.tags
}

resource "aws_launch_template" "ecs_launch_template" {
  name_prefix = "ecs_lt_${var.namespace_suffix}"

  # image_id                             = var.is_arm ? var.arm_ecs_ami : var.x86_ecs_ami
  // Amazon Linux AMI 2.0.20240312 x86_64 ECS HVM GP2
  image_id = "ami-090310a05d8eae025"
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "m5.xlarge"
  # vpc_security_group_ids               = [aws_security_group.service_security_group.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name="lt_${var.namespace_suffix}"
    }
  }
}


resource "aws_ecs_capacity_provider" "ecs_asg_capacity_provider" {
  name = "asg_cap_provider_${var.namespace_suffix}"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg.arn

    managed_scaling {
      maximum_scaling_step_size = 10
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      # Percent. We do not upscale during deploys, so we do not need extra capacity.
      # We put a little less than 100% because otherwise upscales get stuck.
      target_capacity = 99
    }

    managed_termination_protection = "ENABLED"
  }
}