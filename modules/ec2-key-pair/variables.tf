variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "prefix" {
  description = "Name added to all resources"
  type        = string
}

variable "algorithm" {
  type    = string
  default = "RSA"
}

variable "bits" {
  type    = number
  default = 2048
}

variable "key_pair_name" {
  description = "The name of the EC2 Key Pair"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
}