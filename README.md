# AWS WarpStream Terraform module

Terraform module which deploys the WarpStream agent on AWS.

## Usage

There are four resources required to create and deploy a Warpstream agent:

1. `ecs_cluster` - the ECS cluster the service will be deployed into.
1. `s3_bucket` - the S3 bucket backing the agent.
1. `iam_role` - the execution IAM role, which grants access for the running agent to S3.
1. `ecs_service` - the ECS service.
1. `load_balancer` - the LB for the service.

This module exposes configuration variables that control whether the `s3_bucket` `ecs_cluster` and `iam_role` are created, or passed in. Please refer to the `create_s3_bucket`, `create_ecs_cluster` and `create_agent_role` variables to control these.

In most production use cases, these resources will be managed independently.

## Networking

This module will attempt to create an ECS service that runs one agent in each subnet provided. By default, it uses the `visibility` tag to identify which subnets to run on.

If running in a `private` subnet, please pass `vpc_subnet_visibility_tag = "private"` and make sure that your VPC network is set up to allow EGRESS network traffic from the node, to the ECS, or uses a [Private Link](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/vpc-endpoints.html).
