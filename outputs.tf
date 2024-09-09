output "region" {
  description = "The AWS region"
  value       = var.region
}

output "env" {
  description = "The Environment e.g. prod"
  value       = var.env
}

output "prefix" {
  description = "The prefix to all names"
  value       = var.prefix
}

###################### VPC ######################
output "vpc_id" {
  description = "The VPC's ID"
  value       = module.vpc.vpc_id
}

output "default_security_group_id" {
  description = "The default security group for the VPC"
  value       = module.vpc.default_security_group_id
}

output "public_subnets" {
  description = "The VPC's associated public subnets."
  value       = module.vpc.public_subnets
}

########### Control Plane IAM Role ################

output "cp_iam_role_name" {
  value = module.cp_iam_role.iam_role_name
}

output "cp_iam_role_arn" {
  value = module.cp_iam_role.iam_role_arn
}

output "cp_iam_instance_profile_name" {
  value = module.cp_iam_role.iam_instance_profile_name
}

########### Worker Nodes IAM Role ################

output "wn_iam_role_name" {
  value = module.wn_iam_role.iam_role_name
}

output "wn_iam_role_arn" {
  value = module.wn_iam_role.iam_role_arn
}

output "wn_iam_instance_profile_name" {
  value = module.wn_iam_role.iam_instance_profile_name
}

############# ALB Security Group ##################

output "alb_sg_id" {
  value = module.alb_sg.id
}

############# Sub-Domian Cert ##################

output "certificate_body" {
  value = module.sub_domain_cert.certificate_body
}

output "certificate_key" {
  value     = module.sub_domain_cert.certificate_key
  sensitive = true
}

output "certificate_arn" {
  value = module.sub_domain_cert.certificate_arn
}

output "country" {
  value = module.sub_domain_cert.country
}

output "state" {
  value = module.sub_domain_cert.state
}

output "locality" {
  value = module.sub_domain_cert.locality
}

output "organization" {
  value = module.sub_domain_cert.organization
}

output "common_name" {
  value = module.sub_domain_cert.common_name
}

################### Secrets #####################

output "sub_domain_cert_body_secret_name" {
  value = module.secret_sub_domain_cert_body.secret_name
}

output "sub_domain_cert_body_secret_arn" {
  value = module.secret_sub_domain_cert_body.secret_arn
}

output "sub_domain_cert_key_secret_name" {
  value = module.secret_sub_domain_cert_key.secret_name
}

output "sub_domain_cert_key_secret_arn" {
  value = module.secret_sub_domain_cert_key.secret_arn
}

################## ECR #######################

output "ecr_repository_name" {
  value = module.ecr_and_policy.ecr_name
}

output "ecr_repository_arn" {
  value = module.ecr_and_policy.ecr_arn
}

output "ecr_repository_url" {
  value = module.ecr_and_policy.ecr_url
}

############# Control Plane EC2 Key Pair ##################

output "cp_key_pair_name" {
  value = module.cp_ec2_key_pair.key_pair_name
}

output "cp_pem_file_name" {
  value = module.cp_ec2_key_pair.pem_file_name
}

output "cp_pem_file_path" {
  value = module.cp_ec2_key_pair.pem_file_path
}

output "cp_pub_file_name" {
  value = module.cp_ec2_key_pair.pub_file_name
}

output "cp_pub_file_path" {
  value = module.cp_ec2_key_pair.pub_file_path
}

############# Worker Node EC2 Key Pair ##################

output "wn_key_pair_name" {
  value = module.wn_ec2_key_pair.key_pair_name
}

output "wn_pem_file_name" {
  value = module.wn_ec2_key_pair.pem_file_name
}

output "wn_pem_file_path" {
  value = module.wn_ec2_key_pair.pem_file_path
}

output "wn_pub_file_name" {
  value = module.wn_ec2_key_pair.pub_file_name
}

output "wn_pub_file_path" {
  value = module.wn_ec2_key_pair.pub_file_path
}

############# Bastion EC2 Key Pair ##################

output "bastion_key_pair_name" {
  value = module.bastion.key_pair_name
}

output "bastion_pem_file_name" {
  value = module.bastion.pem_file_name
}

output "bastion_pem_file_path" {
  value = module.bastion.pem_file_path
}

########## Kubernetes Cluster ##############

output "cluster_name" {
  value = local.cluster_name
}

############ S3 Ansible SSM ################

# output "s3_ansible_ssm_name" {
#   value = module.s3_ansible_ssm.name
# }

# output "s3_ansible_ssm_arn" {
#   value = module.s3_ansible_ssm.arn
# }
