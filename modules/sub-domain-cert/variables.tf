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

variable "tags" {
  type = map(string)
}