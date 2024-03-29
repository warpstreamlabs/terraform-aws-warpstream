output "lb_domain" {
  description = "AWS Load balancer domain name"
  value       = try(aws_lb.warpstream[0].dns_name, null)
}
