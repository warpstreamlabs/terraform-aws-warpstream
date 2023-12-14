output "bucket_arn" {
  description = "ARN of the bucket"
  value       = aws_s3_bucket.warpstream.arn
}

output "bucket_name" {
  description = "Name (id) of the bucket"
  value       = aws_s3_bucket.warpstream.id
}

#output "bucket_policy_json" {
#  description = "AWS IAM Policy document for the bucket"
#  value       = data.aws_iam_policy_document.warpstream_s3.json
#}
