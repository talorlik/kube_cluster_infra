# Launch Template Outputs
output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.launch_template.id
}

output "launch_template_latest_version" {
  description = "Launch Template Latest Version"
  value       = aws_launch_template.launch_template.latest_version
}

# Autoscaling Outputs
output "autoscaling_group_id" {
  description = "Autoscaling Group ID"
  value       = aws_autoscaling_group.asg.id
}

output "autoscaling_group_name" {
  description = "Autoscaling Group Name"
  value       = aws_autoscaling_group.asg.name
}

output "autoscaling_group_arn" {
  description = "Autoscaling Group ARN"
  value       = aws_autoscaling_group.asg.arn
}

output "cp_private_ip" {
  value = aws_instance.cp_ec2.private_ip
}

output "kube_config_secret_name" {
  value = local.kube_config_secret_name
}

output "kube_dashboard_token_secret_name" {
  value = local.kube_dashboard_token_secret_name
}

output "kube_dashboard_token_secret_tags" {
  value = local.aws_cli_dashboard_tags
}
