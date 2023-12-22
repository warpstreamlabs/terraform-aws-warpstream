data "aws_vpc" "default" {
  count   = var.vpc_id ? 0 : 1
  default = "true"
}

data "aws_vpc" "custom" {
  count = var.vpc_id ? 1 : 0
  id    = var.vpc_id
}

locals {
  az_count   = var.availability_zones
  vpc_id     = var.vpc_id ? var.vpc_id : data.aws_vpc.default[0].id
  cidr_block = var.vpc_id ? data.aws_vpc.custom[0].cidr_block : data.aws_vpc.default[0].cidr_block
}

## Create Internet Gateway for egress/ingress connections to resources in the public subnets
resource "aws_internet_gateway" "default" {
  vpc_id = local.vpc_id
}

## List all AZ available in the region
data "aws_availability_zones" "available" {}

## Public Subnets (one public subnet per AZ)
resource "aws_subnet" "public" {
  count                   = local.az_count
  cidr_block              = cidrsubnet(local.cidr_block, 8, local.az_count + count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = local.vpc_id
  map_public_ip_on_launch = true
}

## Route Table with egress route to the internet
resource "aws_route_table" "public" {
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }
}

## Associate Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

## Make our Route Table the main Route Table
resource "aws_main_route_table_association" "public_main" {
  vpc_id         = local.vpc_id
  route_table_id = aws_route_table.public.id
}

## Creates one Elastic IP per AZ (one for each NAT Gateway in each AZ)
resource "aws_eip" "nat_gateway" {
  count  = local.az_count
  domain = "vpc"
}

## Creates one NAT Gateway per AZ
resource "aws_nat_gateway" "nat_gateway" {
  count         = local.az_count
  subnet_id     = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat_gateway[count.index].id
}

## Private Subnets (one private subnet per AZ)
resource "aws_subnet" "private" {
  count             = local.az_count
  cidr_block        = cidrsubnet(local.cidr_block, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = local.vpc_id
}

## Route to the internet using the NAT Gateway
resource "aws_route_table" "private" {
  count  = local.az_count
  vpc_id = local.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[count.index].id
  }
}

## Associate Route Table with Private Subnets
resource "aws_route_table_association" "private" {
  count          = local.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

## SG for ECS Container Instances
resource "aws_security_group" "ecs_container_instance" {
  name        = "warpstream_ECS_Task_SecurityGroup"
  description = "Security group for ECS task running on Fargate"
  vpc_id      = local.vpc_id

  egress {
    description = "Allow all egress traffic"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}
