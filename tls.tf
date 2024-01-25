resource "tls_private_key" "tls_kafka" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "tls_http" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "tls_http" {
  private_key_pem = tls_private_key.tls_kafka.private_key_pem

  subject {
    common_name  = aws_lb.alb.dns_name
    organization = var.dns_organization
  }

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "tls_self_signed_cert" "tls_kafka" {
  private_key_pem = tls_private_key.tls_kafka.private_key_pem

  subject {
    common_name  = aws_lb.alb.dns_name
    organization = var.dns_organization
  }

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}


resource "aws_acm_certificate" "cert_http" {
  private_key      = tls_private_key.tls_http.private_key_pem
  certificate_body = tls_self_signed_cert.tls_http.cert_pem
}

resource "aws_acm_certificate" "cert_kafka" {
  private_key      = tls_private_key.tls_kafka.private_key_pem
  certificate_body = tls_self_signed_cert.tls_kafka.cert_pem
}

## Default HTTPS listener
resource "aws_lb_listener" "alb_https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.cert_http.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_http.arn
  }
}

## Default HTTPS listener
resource "aws_lb_listener" "nlb_tls" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 9092
  protocol          = "TCP"
  #certificate_arn   = aws_acm_certificate.cert_kafka.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_kafka.arn
  }
}
