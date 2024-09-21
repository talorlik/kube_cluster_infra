locals {
  name = "${var.prefix}-${var.region}-${var.key_pair_name}-${var.env}"
}

resource "tls_private_key" "talo_tls_private_key" {
  algorithm = var.algorithm
  rsa_bits  = var.bits
}

resource "local_file" "private_key" {
  content  = tls_private_key.talo_tls_private_key.private_key_pem
  filename = "${path.module}/${var.region}/${var.env}/${local.name}.pem"
}

resource "local_file" "public_key" {
  content  = tls_private_key.talo_tls_private_key.public_key_pem
  filename = "${path.module}/${var.region}/${var.env}/${local.name}.pub"
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = local.name
  public_key = tls_private_key.talo_tls_private_key.public_key_openssh
  tags = merge(
    {
      Name = "${local.name}"
    },
    var.tags
  )
}