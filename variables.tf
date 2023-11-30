variable "bucket_name" {
  description = "Name of the s3 bucket for the WarpStream Agent. Must be unique."
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster hosting the WarpStream Agent service."
  type        = string
  default     = "warpstream-agent"
}
