variable "bucket_name" {
  description = "Name of the s3 bucket for the WarpStream Agent. Must be unique."
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster hosting the WarpStream Agent service."
  type        = string
  default     = "warpstream-agent"
}

variable "agent_version" {
  description = "Version of the WarpStream Agent."
  type        = string
  default     = "latest"
}

variable "api_key" {
  description = "WarpStream API key"
  type        = string
  sensitive   = true
}

variable "virtual_cluster" {
  description = "WarpStream Virtual Cluster ID."
  type        = string
}
