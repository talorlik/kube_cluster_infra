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

variable "ami" {
  description = "The AMI id to be used in the instance creation"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID into which to deploy the resources"
  type        = string
}

variable "azs" {
  description = "The AZs to choose from into which to deploy the Bastion EC2 machine"
  type        = list(string)
}

variable "public_subnet_id" {
  description = "The public subnet id into which the machine is going to be deployed"
  type        = string
}

variable "tags" {
  type = map(string)
}