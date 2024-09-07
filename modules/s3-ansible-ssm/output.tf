output "name" {
  value = local.name
}

output "arn" {
  value = aws_s3_bucket.ansible_ssm.arn
}