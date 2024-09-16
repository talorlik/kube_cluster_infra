output "key_pair_name" {
  value = aws_key_pair.ec2_key_pair.key_name
}

output "pem_file_name" {
  value = "${local.key_name}.pem"
}

output "pem_file_path" {
  value = "${path.cwd}/${path.module}/${var.region}/${var.env}/${local.key_name}.pem"
}

output "public_ip" {
  value = aws_instance.cp_ec2.public_ip
}