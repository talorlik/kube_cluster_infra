/*
 The terraform {} block contains Terraform settings, including the required providers Terraform will use to provision infrastructure.
 Terraform installs providers from the Terraform Registry by default.
 In this example configuration, the aws provider's source is defined as hashicorp/aws,
*/
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.59.0"
    }
  }

  backend "s3" {
    bucket         = "talo-tf-s3-tfstate"
    key            = "tfstate.json"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "talo-tf-terraform-lock-table"
  }

  required_version = ">= 1.2.0"
}

/*
 The provider block configures the specified provider, in this case aws.
 You can use multiple provider blocks in your Terraform configuration to manage resources from different providers.
*/
provider "aws" {
  region = var.region
}