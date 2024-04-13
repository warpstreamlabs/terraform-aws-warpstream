output "bucket_arn" {
  description = "ARN of the bucket"
  value       = local.bucket_arn
}

output "bucket_name" {
  description = "Name (id) of the bucket"
  value       = var.bucket_name
}
