variable "aws_account" {
  description = "The AWS Account ID"
  type        = string
}

variable "env" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
  description = "Deployment region"
  type        = string
}

variable "prefix" {
  description = "Name added to all resources"
  type        = string
}

###################### VPC #########################

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

################# Control Plane IAM Role ######################

variable "cp_iam_role_name" {
  description = "The name of the IAM Role"
  type        = string
}

variable "cp_iam_role_policy_name" {
  description = "The name of the IAM Role Policy"
  type        = string
}

variable "cp_iam_instance_profile_name" {
  description = "The name of the Instance Profile"
  type        = string
}

variable "cp_iam_assume_role_policy" {
  description = "The IAM assume role policy"
  type        = any
}

################# Worker Nodes IAM Role ######################

variable "wn_iam_role_name" {
  description = "The name of the IAM Role"
  type        = string
}

variable "wn_iam_role_policy_name" {
  description = "The name of the IAM Role Policy"
  type        = string
}

variable "wn_iam_instance_profile_name" {
  description = "The name of the Instance Profile"
  type        = string
}

variable "wn_iam_assume_role_policy" {
  description = "The IAM assume role policy"
  type        = any
}

############# Control Plane Security Group ##################
variable "cp_sg_name" {
  description = "The Name of the Control Plane security group"
  type        = string
}

variable "cp_sg_ingress_rules" {
  description = "List of ingress rules"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string), null)
    security_groups = optional(list(string), null)
  }))
}

variable "cp_sg_egress_rules" {
  description = "List of egress rules"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string), null)
    security_groups = optional(list(string), null)
  }))
}

############## Worker Nodes Security Group ###################
variable "wn_sg_name" {
  description = "The Name of the Worker Nodes security group"
  type        = string
}

variable "wn_sg_ingress_rules" {
  description = "List of ingress rules"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string), null)
    security_groups = optional(list(string), null)
  }))
}

variable "wn_sg_egress_rules" {
  description = "List of egress rules"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string), null)
    security_groups = optional(list(string), null)
  }))
}

############## ALB Security Group ###################
variable "alb_sg_name" {
  description = "The Name of the ALB security group"
  type        = string
}

variable "alb_sg_ingress_rules" {
  description = "List of ingress rules"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string), null)
    security_groups = optional(list(string), null)
  }))
}

########### Control Plane EC2 Key Pair ################

variable "cp_key_pair_name" {
  description = "The name of the Control Plane EC2 Key Pair"
  type        = string
  default     = "cp-key-pair"
}

############ Worker Nodes EC2 Key Pair #################

variable "wn_key_pair_name" {
  description = "The name of the Worker Nodes EC2 Key Pair"
  type        = string
  default     = "wn-key-pair"
}

############ Kubernetes Cluster #################

variable "k8s_version" {
  description = "The version of Kubernetes to deploy."
  type        = string
}

variable "cluster_name" {
  description = "The Name of Kubernetes Cluster"
  type        = string
}

variable "cp_instance_type" {
  description = "The Type of Control Plane EC2 machine"
  type        = string
}

variable "wn_instance_type" {
  description = "The Type of Worker Nodes EC2 machines"
  type        = string
}

variable "cp_associate_public_ip_address" {
  description = "Whether to generate a public IP address for the Control Plane or not"
  type        = bool
  default     = false
}

variable "wn_associate_public_ip_address" {
  description = "Whether to generate a public IP address for the Worker Nodes or not"
  type        = bool
  default     = false
}

variable "sns_protocol" {
  description = "The SNS protocol by which the notification is going to be sent"
  type        = string
}

variable "sns_endpoint" {
  description = "The SNS endpoint to which the notification is going to be sent"
  type        = string
}

############### Sub Domain and Cert ################

variable "country" {
  description = "The country name for the certificate"
  type        = string
}

variable "state" {
  description = "The state name for the certificate"
  type        = string
}

variable "locality" {
  description = "The locality name for the certificate"
  type        = string
}

variable "organization" {
  description = "The organization name for the certificate"
  type        = string
}

variable "common_name" {
  description = "The common name for the certificate"
  type        = string
}

################### Secrets ########################

variable "sub_domain_cert_body_secret_name" {
  description = "The name of the secret"
  type        = string
}

variable "sub_domain_cert_key_secret_name" {
  description = "The name of the secret"
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

##################### ECR ##########################

variable "ecr_name" {
  description = "The name of the ECR"
  type        = string
}

variable "image_tag_mutability" {
  description = "The value that determines if the image is overridable"
  type        = string
}

variable "ecr_lifecycle_policy" {}
# variable "ecr_lifecycle_policy" {
#   description = "The lifecycle policy for the ECR repository"
#   type = object({
#     rules = list(object({
#       rulePriority = number
#       description  = string
#       selection = object({
#         tagStatus       = string
#         tagPrefixList   = optional(list(string), [])
#         countType       = string
#         countNumber     = number
#       })
#       action = object({
#         type = string
#       })
#     }))
#   })
# }