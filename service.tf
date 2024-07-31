locals {
  service_name = "warpstream_agent_${var.namespace_suffix}"
  memory = var.memory * 1024
  cpu = var.cpu * 512

}

resource "aws_ecs_task_definition" "service_task" {
  family                = local.service_name
  container_definitions = <<DEFINITION
  [
    {
      "name": "${local.service_name}_container",
      "image": "public.ecr.aws/warpstream-labs/warpstream_agent:${var.agent_version}",
      "essential": true,
      "portMappings": [
        {
          "name": "warpstream-agent-9092",
          "containerPort": 9092,
          "hostPort": 9092,
          "protocol": "tcp",
          "app_protocol": "http"
        },
        {
          "name": "warpstream-agent-8080",
          "containerPort": 8080,
          "hostPort": 8080,
          "protocol": "tcp",
          "app_protocol": "http"
        }
      ],
      "environment": [
        {
          "name": "WARPSTREAM_API_KEY",
          "value": ${jsonencode(var.api_key)}
        },
        {
          "name": "WARPSTREAM_BUCKET_URL",
          "value": "s3://${var.bucket_name}?region=${local.bucket_region}"
        },
        {
          "name": "WARPSTREAM_DEFAULT_VIRTUAL_CLUSTER_ID",
          "value": ${jsonencode(var.virtual_cluster)}
        },
        {
          "name": "WARPSTREAM_METADATA_URL",
          "value": "https://api.prod.us-east-1.warpstream.com"
        }
      ],
      "memory": ${jsonencode(local.memory)},
      "cpu": ${jsonencode(local.cpu)},
      "command": ["agent"],
      "logConfiguration": {
        "logDriver": "json-file",
        "options": {
            "max-size": "100m",
            "max-file": "10"
        }
      }
    }
  ]
  DEFINITION
  network_mode          = "awsvpc"
  memory                = var.memory * 1024
  cpu                   = var.cpu * 512
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn         = aws_iam_role.ecs_agent_role.arn
}


resource "aws_ecs_service" "ecs_service" {
  name                               = local.service_name
  cluster                            = var.cluster_name
  task_definition                    = aws_ecs_task_definition.service_task.arn
  launch_type                        = "EC2"
  desired_count                      = 1
  force_new_deployment               = true

  enable_execute_command             = true

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = false
    security_groups  = [] # TODO
  }


  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }
}


# module "ecs_service" {
#   source = "terraform-aws-modules/ecs/aws//modules/service"

#   name        = local.service_name
#   cluster_arn     = local.cluster_arn

#   desired_count            = 1
#   # cpu                      = var.cpu * 1024
#   # memory                   = var.memory * 1024
#   force_new_deployment     = true
#   # requires_compatibilities = ["EC2"]
  
#   launch_type              = "EC2"
#   network_mode             = "awsvpc"
#   runtime_platform = {
#     cpu_architecture        = "X86_64"
#     operating_system_family = "LINUX"
#   }
#   task_definition_arn = aws_ecs_task_definition.service_task.arn

#   create_tasks_iam_role = false
#   tasks_iam_role_arn    = local.agent_role_arn

#   subnet_ids = local.subnet_ids
#   security_group_rules = {
#     ingress_http = {
#       type        = "ingress"
#       from_port   = 9092
#       to_port     = 9092
#       protocol    = "tcp"
#       description = "Service port"
#       #source_security_group_id = module.ingress.security_group_id
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#     # Allow all egress.
#     egress_all = {
#       type        = "egress"
#       from_port   = 0
#       to_port     = 0
#       protocol    = "-1"
#       cidr_blocks = ["0.0.0.0/0"]
#       ipv6_cidr_blocks = ["::/0"]
#     }
#   }

#   tags = merge(local.tags, {
#     ServiceName = local.service_name
#   })
  

#   load_balancer = var.create_lb ? { 
#     "lb1": {
#       target_group_arn = aws_lb_target_group.warpstream_agent[0].arn
#       container_name   = "warpstream-agent"
#       container_port   = 9092
#     }
#   }: {}
# }

