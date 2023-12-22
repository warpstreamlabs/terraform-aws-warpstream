output "bucket_arn" {
  description = "ARN of the bucket"
  value       = aws_s3_bucket.warpstream.arn
}

output "bucket_name" {
  description = "Name (id) of the bucket"
  value       = aws_s3_bucket.warpstream.id
}

output "alb_domain" {
  description = "AWS Application Load Balancer domain name"
  value       = aws_lb.alb.dns_name
}

output "nlb_domain" {
  description = "AWS Network Load Balancer domain name"
  value       = aws_lb.nlb.dns_name
}
