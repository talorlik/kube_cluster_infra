output "secret_name" {
  value = aws_secretsmanager_secret.sm_secret.name
}

output "secret_arn" {
  description = "The ARN of the secret"
  value       = aws_secretsmanager_secret.sm_secret.arn
}