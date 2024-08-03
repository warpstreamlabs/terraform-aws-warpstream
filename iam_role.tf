data "aws_iam_policy_document" "access" {
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
      "${local.bucket_arn}",
      "${local.bucket_arn}/*",
    ]
  }
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "access" {
  count  = var.create_agent_role ? 1 : 0
  name   = var.agent_role_name
  policy = data.aws_iam_policy_document.access.json
}

locals {
  agent_role_arn = var.create_agent_role ? module.agent[0].iam_role_arn : data.aws_iam_role.agent[0].arn
}

data "aws_iam_role" "agent" {
  count = var.create_agent_role ? 0 : 1
  name  = var.agent_role_name
}

module "agent" {
  count = var.create_agent_role ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = ">= 5.1.0"

  create_role = true

  role_name = var.agent_role_name

  create_custom_role_trust_policy = true
  custom_role_trust_policy        = data.aws_iam_policy_document.trust.json

  custom_role_policy_arns = [aws_iam_policy.access[0].arn, ]
}

# ECS stuff

resource "aws_iam_role" "ecs_agent_role" {
  name_prefix        = "ecs_agent_${var.namespace_suffix}"
  assume_role_policy = data.aws_iam_policy_document.ecs_agent_policy_doc.json
}

data "aws_iam_policy_document" "ecs_agent_policy_doc" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [
        "ec2.amazonaws.com", 
        "ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_agent_policy_attach" {
  role       = aws_iam_role.ecs_agent_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_agent_instance_profile" {
  name_prefix = "ecs_agent_${var.namespace_suffix}"
  role        = aws_iam_role.ecs_agent_role.name
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name_prefix        = "ecs_task_execution_${var.namespace_suffix}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role_policy.json
}

data "aws_iam_policy_document" "ecs_task_execution_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_s3_policy_document" {
  statement {
    sid     = "S3ReadPermissionsAndObjectPermissions"
    actions = ["s3:Get*", "s3:List*", "s3:*Object"]

    effect = "Allow"
    resources = ["arn:aws:s3:::${var.bucket_name}"]
  }
}

resource "aws_iam_policy" "ecs_task_s3_policy" {
  count       = 1
  name_prefix = "ecs_task_s3_policy_${var.namespace_suffix}"
  path        = "/"
  description = "Gives ECS tasks (service containers) permissions to use S3"

  policy = data.aws_iam_policy_document.ecs_task_s3_policy_document.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_policy" {
  count      = 1
  role       = aws_iam_role.ecs_agent_role.name
  policy_arn = aws_iam_policy.ecs_task_s3_policy[0].arn
}