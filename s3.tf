locals {
  bucket_region = var.create_bucket ? aws_s3_bucket.warpstream[0].region : data.aws_s3_bucket.warpstream[0].region
  bucket_arn    = var.create_bucket ? aws_s3_bucket.warpstream[0].arn : data.aws_s3_bucket.warpstream[0].arn

  tags = {
    "Managed-By" = "warpstream"
  }
}

data "aws_s3_bucket" "warpstream" {
  count  = var.create_bucket ? 0 : 1
  bucket = var.bucket_name
}

resource "aws_s3_bucket" "warpstream" {
  count  = var.create_bucket ? 1 : 0
  bucket = var.bucket_name

  tags = merge(local.tags, {
    Name = var.bucket_name
  })
}

resource "aws_s3_bucket_metric" "warpstream" {
  count = var.create_bucket ? 1 : 0

  bucket = aws_s3_bucket.warpstream[0].id
  name   = "EntireBucket"
}

resource "aws_s3_bucket_lifecycle_configuration" "warpstream" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.warpstream[0].id

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
