variable "env" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
  description = "Deployment region"
  type        = string
  default     = "us-east-1"
}

variable "prefix" {
  description = "Name added to all resources"
  type        = string
}

variable "k8s_version" {
  description = "The version of Kubernetes to deploy. Defaults to v1.30."
  type        = string
}

variable "cluster_name" {
  description = "The Name of Kubernetes Cluster"
  type        = string
}

variable "join_secret_name" {
  description = "The Name of the join secret"
  type        = string
}

variable "kube_config_secret_name" {
  description = "The Name of the Kube Config secret"
  type        = string
}

variable "kube_dashboard_token_secret_name" {
  description = "The Name of the Kube Config secret"
  type        = string
}

variable "ami" {
  description = "The AMI id to be used in the instance creation"
  type        = string
}

variable "cp_instance_type" {
  description = "Instance Type"
  type        = string
}

variable "cp_azs" {
  description = "The AZs into which to deploy the Control Plane EC2 machines"
  type        = list(string)
}

variable "cp_vpc_security_group_ids" {
  description = "A list of security group IDs"
  type        = list(string)
}

variable "cp_key_pair_name" {
  description = "The name of the EC2 Key Pair"
  type        = string
}

variable "cp_private_subnets" {
  description = "A list of subnets into which the Control Plane EC2 machines will be deployed"
  type        = list(string)
}

variable "cp_iam_instance_profile_name" {
  description = "The Name of the IAM Role Profile to be used"
  type        = string
}

variable "cp_associate_public_ip_address" {
  description = "Whether to generate a public IP address for the Control Plane or not"
  type        = bool
  default     = false
}

variable "root_block_device" {
  description = "EC2 root block device settings"
  type = object({
    delete_on_termination = optional(bool, true)
    encrypted             = optional(bool, false)
    iops                  = optional(number, 3000)
    kms_key_id            = optional(string)
    tags                  = optional(map(string))
    throughput            = optional(number)
    volume_size           = optional(number, 20)
    volume_type           = optional(string, "gp3")
  })
  default = {
    iops        = 3000
    volume_size = 20
    volume_type = "gp3"
  }
}

variable "cp_instance_name" {
  description = "The Name of Control Plane EC2 machine"
  type        = string
  default     = "control-plane"
}

variable "launch_template_name" {
  description = "The Name of the Launch Template"
  type        = string
  default     = "launch-template"
}

variable "launch_template_description" {
  type    = string
  default = "Launch a Worker Node EC2 Instance plus User Data to bootstrap the node"
}

variable "wn_instance_type" {
  description = "Instance Type"
  type        = string
}

variable "wn_iam_instance_profile_name" {
  description = "The Name of the IAM Role Profile to be used"
  type        = string
}

variable "wn_key_pair_name" {
  description = "The name of the EC2 Key Pair"
  type        = string
}

variable "ebs_optimized" {
  description = "Start with an optimized EBS"
  type        = bool
  default     = true
}

variable "update_default_version" {
  description = "Determine whether to start with the latest template version"
  type        = bool
  default     = true
}

variable "block_device_mappings" {
  description = "EC2 block device mappings settings"
  type = list(object({
    device_name = string
    ebs = optional(object({
      delete_on_termination = optional(bool, true)
      encrypted             = optional(bool, false)
      iops                  = optional(number)
      kms_key_id            = optional(string)
      snapshot_id           = optional(string)
      throughput            = optional(number)
      volume_size           = optional(number)
      volume_type           = optional(string)
    }))
    no_device    = optional(string)
    virtual_name = optional(string)
  }))
  default = [
    {
      device_name = "/dev/sda1"
      ebs = {
        volume_size           = 20
        delete_on_termination = true
        volume_type           = "gp3"
        iops                  = 3000
      }
    }
  ]
}

variable "monitoring" {
  description = "Enable monitoring"
  type = object({
    enabled = bool
  })
  default = {
    enabled = true
  }
}

variable "wn_associate_public_ip_address" {
  description = "Whether to generate a public IP address for the Worker Nodes or not"
  type        = bool
  default     = false
}

variable "wn_vpc_security_group_ids" {
  description = "A list of security group IDs"
  type        = list(string)
}

variable "wn_instance_name" {
  description = "The Name of Worker Nodes EC2 machines"
  type        = string
  default     = "worker-node"
}

variable "asg_name" {
  description = "The Name of the Auto Scaling Group"
  type        = string
  default     = "asg"
}

variable "desired_capacity" {
  description = "The initial number of instances needed"
  type        = number
  default     = 1
}

variable "min_size" {
  description = "The Min number of instances required to be running"
  type        = number
  default     = 0
}

variable "max_size" {
  description = "The Max number of instances allowed"
  type        = number
  default     = 2
}

variable "wn_private_subnets" {
  description = "A list of subnets into which the Worker Nodes EC2 machines will be deployed"
  type        = list(string)
}

variable "health_check_type" {
  description = "The type of health check that is required"
  type        = string
  default     = "EC2"
}

variable "instance_refresh" {
  description = "Configuration for instance refresh"
  type = object({
    strategy = string,
    preferences = optional(object({
      checkpoint_delay       = optional(number, 3600),
      checkpoint_percentages = optional(list(number)),
      instance_warmup        = optional(number),
      max_healthy_percentage = optional(number, 100),
      min_healthy_percentage = optional(number, 90),
      skip_matching          = optional(bool, false),
      auto_rollback          = optional(bool, false),
      alarm_specification = optional(object({
        alarms = list(string)
      })),
      scale_in_protected_instances = optional(string, "Ignore"),
      standby_instances            = optional(string, "Ignore")
    })),
    triggers = optional(set(string))
  })
  default = {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = 50
    }
    triggers = ["desired_capacity", "launch_template"]
  }
}

variable "sns_topic_name" {
  description = "The Name of the SNS Topic that will be used for notifications"
  type        = string
  default     = "sns-topic"
}

variable "sns_protocol" {
  description = "The SNS protocol by which the notification is going to be sent"
  type        = string
}

variable "sns_endpoint" {
  description = "The SNS endpoint to which the notification is going to be sent"
  type        = string
}

variable "autoscaling_policy_name" {
  description = "The Name of the Autoscaling Policy"
  type        = string
  default     = "avg-cpu-policy"
}

variable "notifications" {
  description = "The types of notifications that will be sent"
  type        = list(string)
  default = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
}

variable "policy_type" {
  description = "The type of autoscaling policy"
  type        = string
  default     = "TargetTrackingScaling"
}

variable "target_tracking_configuration" {
  description = "Configuration for target tracking scaling policy"
  type = object({
    predefined_metric_specification = optional(object({
      predefined_metric_type = string
      resource_label         = optional(string)
    }))
    customized_metric_specification = optional(object({
      metric_dimension = optional(map(string))
      metric_name      = optional(string)
      namespace        = optional(string)
      statistic        = optional(string)
      unit             = optional(string)
      metrics = optional(list(object({
        id         = string
        expression = optional(string)
      })))
    }))
    target_value     = number
    disable_scale_in = optional(bool, false)
  })

  default = {
    predefined_metric_specification = {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = 50.0
    disable_scale_in = false
  }
}

variable "tags" {
  type = map(string)
}