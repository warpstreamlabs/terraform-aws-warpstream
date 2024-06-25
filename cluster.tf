locals {
  cluster_arn = var.create_cluster ? aws_ecs_cluster.warpstream[0].arn : data.aws_ecs_cluster.warpstream[0].arn
  cli_zip = "awscli-exe-linux-x86_64.zip"
  provision_ec2_command_list = var.create_cluster ? [
  "#!/bin/bash",

  # Bump this to force refreshes if needed.
  "echo force_refresh_1",

  # ECS stuff
  # 
  # Tell the ECS agent which ECS cluster to connect to.
  "echo ECS_CLUSTER=${aws_ecs_cluster.warpstream[0].name} >> /etc/ecs/ecs.config",
  # Configure per-service values for ECS_CONTAINER_STOP_TIMEOUT:
  # https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/load-balancer-connection-draining.html
  # "echo ECS_CONTAINER_STOP_TIMEOUT=${var.ecs_container_stop_timeout} >> /etc/ecs/ecs.config",
  # Configure log rotation to be size-based cause we log alot and otherwise we'll run out of disk space.
  "echo ECS_LOG_ROLLOVER_TYPE=size >> /etc/ecs/ecs.config",
  "echo ECS_LOG_MAX_FILE_SIZE_MB=100 >> /etc/ecs/ecs.config",
  "echo ECS_LOG_MAX_ROLL_COUNT=10 >> /etc/ecs/ecs.config",

  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/automated_image_cleanup.html#automated_image_cleanup_parameters
  # 
  # So we don't run out of disk space.
  "echo ECS_ENGINE_TASK_CLEANUP_WAIT_DURATION=30m >> /etc/ecs/ecs.config",
  "echo ECS_IMAGE_CLEANUP_INTERVAL=10m >> /etc/ecs/ecs.config",
  "echo ECS_IMAGE_MINIMUM_CLEANUP_AGE=30m >> /etc/ecs/ecs.config",
  "echo ECS_NUM_IMAGES_DELETE_PER_CYCLE=10 >> /etc/ecs/ecs.config",

] : []

  provision_ec2_command_script = join("\n", local.provision_ec2_command_list)
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
  max_size = 3
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

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_agent_instance_profile.arn
  }
  # image_id                             = var.is_arm ? var.arm_ecs_ami : var.x86_ecs_ami
  // Amazon Linux AMI 2.0.20240312 x86_64 ECS HVM GP2
  image_id = "ami-090310a05d8eae025"
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "m5.xlarge"
  
  user_data = base64encode(local.provision_ec2_command_script)
  
  # vpc_security_group_ids               = [aws_security_group.service_security_group.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name="lt_${var.namespace_suffix}"
    }
  }
}
