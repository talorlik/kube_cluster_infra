output "key_pair_name" {
  value = aws_key_pair.ec2_key_pair.key_name
}

output "pem_file_name" {
  value = "${local.name}.pem"
}

output "pem_file_path" {
  value = "${path.cwd}/${path.module}/${var.region}/${var.env}/${local.name}.pem"
}

output "pub_file_name" {
  value = "${local.name}.pub"
}

output "pub_file_path" {
  value = "${path.cwd}/${path.module}/${var.region}/${var.env}/${local.name}.pub"
}