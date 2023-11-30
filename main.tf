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
