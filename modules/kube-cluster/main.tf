locals {
  cp_ec2_name                      = "${var.prefix}-${var.region}-${var.cp_instance_name}-${var.env}"
  launch_template_name             = "${var.prefix}-${var.region}-${var.launch_template_name}-${var.env}"
  wn_ec2_name                      = "${var.prefix}-${var.region}-${var.wn_instance_name}-${var.env}"
  asg_name                         = "${var.prefix}-${var.region}-${var.asg_name}-${var.env}"
  sns_topic_name                   = "${var.prefix}-${var.region}-${var.sns_topic_name}-${var.env}"
  autoscaling_policy_name          = "${var.prefix}-${var.region}-${var.autoscaling_policy_name}-${var.env}"
  join_secret_name                 = "${var.prefix}/${var.region}/${var.join_secret_name}/${var.env}"
  kube_config_secret_name          = "${var.prefix}/${var.region}/${var.kube_config_secret_name}/${var.env}"
  kube_dashboard_token_secret_name = "${var.prefix}/${var.region}/${var.kube_dashboard_token_secret_name}/${var.env}"
  join_tags = merge(
    {
      Name = local.join_secret_name
    },
    var.tags
  )
  config_tags = merge(
    {
      Name = local.kube_config_secret_name
    },
    var.tags
  )
  dashboard_tags = merge(
    {
      Name = local.kube_dashboard_token_secret_name
    },
    var.tags
  )
  aws_cli_join_tags = join(" ", [
    for key, value in local.join_tags : "Key=${key},Value=${tostring(value)}"
  ])
  aws_cli_config_tags = join(" ", [
    for key, value in local.config_tags : "Key=${key},Value=${tostring(value)}"
  ])
  aws_cli_dashboard_tags = join(" ", [
    for key, value in local.dashboard_tags : "Key=${key},Value=${tostring(value)}"
  ])
  # Using a template to dynamically generate the userdata deployment script
  cp_user_data = templatefile("${path.module}/cp_bootstrap.sh.tftpl", {
    aws_region                       = var.region
    k8s_version                      = var.k8s_version
    cluster_name                     = var.cluster_name
    join_secret_name                 = local.join_secret_name
    join_secret_tags                 = local.aws_cli_join_tags
    kube_config_secret_name          = local.kube_config_secret_name
    kube_config_secret_tags          = local.aws_cli_config_tags
    kube_dashboard_token_secret_name = local.kube_dashboard_token_secret_name
    kube_dashboard_token_secret_tags = local.aws_cli_dashboard_tags
  })
  wn_user_data = templatefile("${path.module}/wn_bootstrap.sh.tftpl", {
    aws_region       = var.region
    k8s_version      = var.k8s_version
    join_secret_name = local.join_secret_name
  })
}

################## Control Plane EC2 ########################
resource "aws_instance" "cp_ec2" {
  ami                         = var.ami
  instance_type               = var.cp_instance_type
  availability_zone           = var.cp_azs[0]
  vpc_security_group_ids      = var.cp_vpc_security_group_ids
  key_name                    = var.cp_key_pair_name
  subnet_id                   = var.cp_private_subnets[0]
  iam_instance_profile        = var.cp_iam_instance_profile_name
  user_data                   = local.cp_user_data
  associate_public_ip_address = var.cp_associate_public_ip_address
  ebs_optimized               = true

  root_block_device {
    iops        = try(var.root_block_device.iops, null)
    volume_size = try(var.root_block_device.volume_size, null)
    volume_type = try(var.root_block_device.volume_type, null)
  }

  tags = merge(
    {
      Name                                        = local.cp_ec2_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      "node-role.kubernetes.io/control-plane"     = 1
    },
    var.tags
  )
}

################## Launch Template ########################
resource "aws_launch_template" "launch_template" {
  name          = local.launch_template_name
  description   = var.launch_template_description
  image_id      = var.ami
  instance_type = var.wn_instance_type

  iam_instance_profile {
    name = var.wn_iam_instance_profile_name
  }

  # vpc_security_group_ids = [aws_security_group.yolo5_ec2_sg.id]
  key_name               = var.wn_key_pair_name
  user_data              = base64encode(local.wn_user_data)
  ebs_optimized          = var.ebs_optimized
  update_default_version = var.update_default_version

  dynamic "block_device_mappings" {
    for_each = var.block_device_mappings
    content {
      device_name = block_device_mappings.value.device_name

      dynamic "ebs" {
        for_each = block_device_mappings.value.ebs != null ? [block_device_mappings.value.ebs] : []
        content {
          delete_on_termination = try(ebs.value.delete_on_termination, true)
          iops                  = try(ebs.value.iops, null)
          volume_size           = try(ebs.value.volume_size, null)
          volume_type           = try(ebs.value.volume_type, null)
        }
      }
    }
  }

  monitoring {
    enabled = var.monitoring.enabled
  }

  network_interfaces {
    associate_public_ip_address = var.wn_associate_public_ip_address
    security_groups             = var.wn_vpc_security_group_ids
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name                                        = local.wn_ec2_name
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
        "node-role.kubernetes.io/node"              = 1
      },
      var.tags
    )
  }

  tags = merge(
    {
      Name = local.launch_template_name
    },
    var.tags
  )
}

################## Autoscaling Group #####################
resource "aws_autoscaling_group" "asg" {
  name                = local.asg_name
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = var.wn_private_subnets
  health_check_type   = var.health_check_type

  # Launch Template
  launch_template {
    id      = aws_launch_template.launch_template.id
    version = aws_launch_template.launch_template.latest_version
  }
  # Instance Refresh
  instance_refresh {
    strategy = var.instance_refresh.strategy

    dynamic "preferences" {
      for_each = var.instance_refresh.preferences == null ? [] : [var.instance_refresh.preferences]
      content {
        min_healthy_percentage = try(preferences.value.min_healthy_percentage, null)
      }
    }

    triggers = try(var.instance_refresh.triggers, null)
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

################# Autoscaling Notifications ##################

################### SNS - Topic ########################
resource "aws_sns_topic" "sns_topic" {
  name = local.sns_topic_name
}

################## SNS - Subscription ##################
resource "aws_sns_topic_subscription" "sns_topic_subscription" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = var.sns_protocol
  endpoint  = var.sns_endpoint
}

############### Autoscaling Notification ################
resource "aws_autoscaling_notification" "notifications" {
  group_names   = [aws_autoscaling_group.asg.id]
  notifications = var.notifications
  topic_arn     = aws_sns_topic.sns_topic.arn
}

############# Target Tracking Scaling Policies ###########
# TTS - Scaling Policy-1: Based on CPU Utilization
resource "aws_autoscaling_policy" "avg_cpu_policy" {
  name = local.autoscaling_policy_name
  # The policy type may be either "SimpleScaling", "StepScaling" or "TargetTrackingScaling". If this value isn't provided, AWS will default to "SimpleScaling."
  policy_type            = var.policy_type
  autoscaling_group_name = aws_autoscaling_group.asg.id
  # CPU Utilization is above 50
  target_tracking_configuration {
    dynamic "predefined_metric_specification" {
      for_each = var.target_tracking_configuration.predefined_metric_specification == null ? [] : [var.target_tracking_configuration.predefined_metric_specification]
      content {
        predefined_metric_type = predefined_metric_specification.value.predefined_metric_type
      }
    }
    target_value     = var.target_tracking_configuration.target_value
    disable_scale_in = var.target_tracking_configuration.disable_scale_in
  }
}