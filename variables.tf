variable "bucket_name" {
  description = "Name of the s3 bucket for the WarpStream Agent. Must be unique."
  type        = string
}

variable "create_bucket" {
  description = "Whether or not to create a new s3 bucket. If set to false, requires the s3 bucket is created separately"
  default     = false
}

variable "cluster_name" {
  description = "Name of the ECS cluster hosting the WarpStream Agent service."
  type        = string
  default     = "warpstream-agent"
}

variable "create_cluster" {
  description = "Whether or not to create a new ECS bucket. If set to false, requires the ECS cluster is created separately"
  default     = false
}

variable "agent_role_name" {
  description = "Name of the agent role for ECS"
  type        = string
  default     = "warpstream-agent"
}

variable "create_agent_role" {
  description = "Whether or not to create agent role."
  type        = bool
  default     = false
}

variable "agent_version" {
  description = "Version of the WarpStream Agent."
  type        = string
  default     = "latest"
}

variable "create_lb" {
  description = "Whether or not to create load balancer."
  type        = bool
  default     = false
}

variable "lb_name" {
  description = "Name of the load balancer"
  type        = string
  default     = "warpstream-agent"
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

variable "cpu" {
  description = "Number of requested CPU cores"
  type        = number
  default     = 4
}

variable "memory" {
  description = "Requested Memory in GiB"
  type        = number
  default     = 16
}

variable "vpc_id" {
  description = "ID of the VPC for the ECS cluster. The default VPC is used if not provided."
  type        = string
  default     = null
}

variable "vpc_subnet_visibility_tag" {
  description = "Visibility tag to look up subnets on, within the ECS cluster."
  type        = string
  default     = "public"
}
