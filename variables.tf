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

variable "agent_pool_name" {
  description = "WarpStream Agent Pool Name."
  type        = string
}

variable "cpu" {
  description = "Number of requested CPU cores"
  type        = number
  default     = 4
}

variable "memory" {
  description = "Requested Memroy in GiB"
  type        = number
  default     = 16
}

variable "vpc_subnets" {
  description = "IDs of the VPC subnets for the ECS cluster. All subnets from the default VPC are used if not provided."
  type        = list(string)
  default     = []
}
