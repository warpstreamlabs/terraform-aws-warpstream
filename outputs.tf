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

output "alb_domain" {
  description = "AWS Application Load Balancer domain name"
  value       = aws_lb.alb.dns_name
}

output "nlb_domain" {
  description = "AWS Network Load Balancer domain name"
  value       = aws_lb.nlb.dns_name
}
