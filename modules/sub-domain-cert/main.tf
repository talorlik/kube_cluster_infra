resource "tls_private_key" "pkey" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "ss_cert" {
  private_key_pem = tls_private_key.pkey.private_key_pem

  subject {
    country      = var.country
    province     = var.state
    locality     = var.locality
    organization = var.organization
    common_name  = var.common_name
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "acm_cert" {
  private_key      = tls_private_key.pkey.private_key_pem
  certificate_body = tls_self_signed_cert.ss_cert.cert_pem

  tags = merge(
    {
      Name = var.common_name
    },
    var.tags
  )
}
