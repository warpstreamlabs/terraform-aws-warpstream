output "bucket_arn" {
  description = "ARN of the bucket"
  value       = aws_s3_bucket.warpstream.arn
}

output "bucket_name" {
  description = "Name (id) of the bucket"
  value       = aws_s3_bucket.warpstream.id
}
