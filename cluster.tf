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

resource "aws_autoscaling_group" "ecs_asg" {
  count = var.create_cluster ? 1 : 0
  name_prefix = "asg_${var.namespace_suffix}"
  max_size = 10
  min_size = 1
  health_check_type         = "EC2"

  vpc_zone_identifier = var.subnet_ids
  launch_template {
    id      = aws_launch_template.ecs_launch_template[count.index].id
    version = aws_launch_template.ecs_launch_template[count.index].latest_version
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

resource "aws_ecs_cluster_capacity_providers" "service_ecs_cluster_capacity_provider" {
  count = var.create_cluster ? 1 : 0
  cluster_name = aws_ecs_cluster.warpstream[count.index].name

  capacity_providers = [aws_ecs_capacity_provider.ecs_asg_capacity_provider[count.index].name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.ecs_asg_capacity_provider[count.index].name
  }
}

resource "aws_ecs_capacity_provider" "ecs_asg_capacity_provider" {
  count = var.create_cluster ? 1 : 0
  name = "asg_cap_provider_${var.namespace_suffix}"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_asg[count.index].arn

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

resource "aws_launch_template" "ecs_launch_template" {
  count = var.create_cluster ? 1 : 0
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
