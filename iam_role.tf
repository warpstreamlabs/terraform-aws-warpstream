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
