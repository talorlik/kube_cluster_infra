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

variable "name" {
  description = "The Name of the Security Group for the EC2"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID into which to deploy the resources"
  type        = string
}

variable "ingress_rules" {
  description = "List of ingress rules"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = list(string)
    security_groups = list(string)
  }))
}

variable "egress_rules" {
  description = "List of egress rules"
  type = list(object({
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = list(string)
    security_groups = list(string)
  }))
}

variable "tags" {
  type = map(string)
}