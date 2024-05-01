locals {
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.subnets.ids
}
