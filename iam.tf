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

data "aws_iam_role" "ecs" {
  name = "ecsTaskExecutionRole"
}
