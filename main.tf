data "aws_availability_zones" "available" {
  state = "available"
}

module "ubuntu_24_04_latest" {
  source              = "github.com/andreswebs/terraform-aws-ami-ubuntu"
  arch                = "amd64"
  ubuntu_version      = "24.04"
  virtualization_type = "hvm"
  volume_type         = "ebs-gp3"
}

locals {
  vpc_name     = "${var.prefix}-${var.region}-vpc-${var.env}"
  igw_name     = "${var.prefix}-${var.region}-igw-${var.env}"
  cluster_name = "${var.prefix}-${var.region}-${var.cluster_name}-${var.env}"
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)
  cp_azs       = slice(local.azs, 0, 1)
  wn_azs       = slice(local.azs, 1, 3)
  ami_id       = module.ubuntu_24_04_latest.ami_id
  tags = {
    Env       = "${var.env}"
    Terraform = "true"
  }
}

# Output: public_subnets for use in ALB
module "vpc" {
  source         = "terraform-aws-modules/vpc/aws"
  name           = local.vpc_name
  cidr           = var.vpc_cidr
  azs            = local.azs
  public_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 1)]
  public_subnet_tags = {
    "kubernetes.io/role/alb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
  igw_tags = {
    Name = "${local.igw_name}"
  }
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 10)]
  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
  enable_nat_gateway = true
  single_nat_gateway = true
  nat_gateway_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  enable_dhcp_options      = true
  dhcp_options_domain_name = "ec2.internal"

  tags = local.tags
}

# Probe to check if NAT Gateway and Internet Gateway are operational
resource "null_resource" "check_gateways" {
  provisioner "local-exec" {
    command = <<EOT
attempts=0
max_attempts=30
while ! curl -s --head --request GET http://www.google.com | grep "200 OK" > /dev/null; do
  echo "Waiting for internet connectivity via NAT Gateway..."
  sleep 10
  attempts=$((attempts+1))
  if [ $attempts -ge $max_attempts ]; then
    echo "Timeout waiting for internet connectivity."
    exit 1
  fi
done
echo "NAT Gateway and Internet Gateway are operational."
EOT
  }

  depends_on = [
    module.vpc,           # Ensure the probe waits for the VPC module
    module.vpc.natgw_ids, # Ensure NAT Gateway is up
    module.vpc.igw_id     # Ensure Internet Gateway is up
  ]
}

################## Control Plane IAM Role ######################

module "cp_iam_role" {
  source = "./modules/cp-iam-role-and-policy"

  env                       = var.env
  region                    = var.region
  prefix                    = var.prefix
  iam_role_name             = var.cp_iam_role_name
  assume_role_policy        = var.cp_iam_assume_role_policy
  iam_role_policy_name      = var.cp_iam_role_policy_name
  iam_instance_profile_name = var.cp_iam_instance_profile_name
  tags                      = local.tags
}

################## Worker Nodes IAM Role ######################

module "wn_iam_role" {
  source = "./modules/wn-iam-role-and-policy"

  env                       = var.env
  region                    = var.region
  prefix                    = var.prefix
  iam_role_name             = var.wn_iam_role_name
  assume_role_policy        = var.wn_iam_assume_role_policy
  iam_role_policy_name      = var.wn_iam_role_policy_name
  iam_instance_profile_name = var.wn_iam_instance_profile_name
  tags                      = local.tags
}

############# Control Plane Security Group ##################
module "cp_sg" {
  source = "./modules/security-group"

  env           = var.env
  region        = var.region
  prefix        = var.prefix
  name          = var.cp_sg_name
  vpc_id        = module.vpc.vpc_id
  ingress_rules = var.cp_sg_ingress_rules
  egress_rules  = var.cp_sg_egress_rules
  tags = merge(
    {
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    },
    local.tags
  )
}

############# Worker Nodes Security Group ##################
module "wn_sg" {
  source = "./modules/security-group"

  env           = var.env
  region        = var.region
  prefix        = var.prefix
  name          = var.wn_sg_name
  vpc_id        = module.vpc.vpc_id
  ingress_rules = var.wn_sg_ingress_rules
  egress_rules  = var.wn_sg_egress_rules
  tags = merge(
    {
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    },
    local.tags
  )
}

########## Additional rules for Security Groups ##########
################### Control Plane ########################
resource "aws_vpc_security_group_ingress_rule" "cp_kube_api_from_wn" {
  security_group_id            = module.cp_sg.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.wn_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "cp_etcd_from_self" {
  security_group_id            = module.cp_sg.id
  from_port                    = 2379
  to_port                      = 2380
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.cp_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "cp_kubelet_api_from_wn" {
  security_group_id            = module.cp_sg.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.wn_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "cp_kube_controller_manager_from_self" {
  security_group_id            = module.cp_sg.id
  from_port                    = 10257
  to_port                      = 10257
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.cp_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "cp_kube_scheduler_from_self" {
  security_group_id            = module.cp_sg.id
  from_port                    = 10259
  to_port                      = 10259
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.cp_sg.id
}

################### Worker Nodes ########################
resource "aws_vpc_security_group_ingress_rule" "wn_kubelet_api_from_cp" {
  security_group_id            = module.wn_sg.id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.cp_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "wn_kube_proxy_from_cp" {
  security_group_id            = module.wn_sg.id
  from_port                    = 10256
  to_port                      = 10256
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.cp_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "wn_flannel_vxlan_from_wn" {
  security_group_id            = module.wn_sg.id
  from_port                    = 8472
  to_port                      = 8472
  ip_protocol                  = "udp"
  referenced_security_group_id = module.wn_sg.id
}

################ ALB Security Group #####################
module "alb_sg" {
  source = "./modules/security-group"

  env           = var.env
  region        = var.region
  prefix        = var.prefix
  name          = var.alb_sg_name
  vpc_id        = module.vpc.vpc_id
  ingress_rules = var.alb_sg_ingress_rules
  egress_rules  = []
  tags = merge(
    {
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    },
    local.tags
  )
}

resource "aws_vpc_security_group_egress_rule" "alb_direct_traffic_to_worker_nodes" {
  security_group_id            = module.alb_sg.id
  from_port                    = 8443
  to_port                      = 8443
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.wn_sg.id
}

########### Control Plane EC2 Key Pair ###############

module "cp_ec2_key_pair" {
  source        = "./modules/ec2-key-pair"
  env           = var.env
  region        = var.region
  prefix        = var.prefix
  key_pair_name = var.cp_key_pair_name
  tags          = local.tags
}

########### Worker Nodes EC2 Key Pair ###############

module "wn_ec2_key_pair" {
  source        = "./modules/ec2-key-pair"
  env           = var.env
  region        = var.region
  prefix        = var.prefix
  key_pair_name = var.wn_key_pair_name
  tags          = local.tags
}

############ Kubernetes Cluster ##################

locals {
  cp_private_subnet = slice(module.vpc.private_subnets, 0, 1)
  wn_private_subnet = slice(module.vpc.private_subnets, 1, 3)
}

module "kube_cluster" {
  source                           = "./modules/kube-cluster"
  env                              = var.env
  region                           = var.region
  prefix                           = var.prefix
  k8s_version                      = var.k8s_version
  cluster_name                     = local.cluster_name
  join_secret_name                 = var.join_secret_name
  kube_config_secret_name          = var.kube_config_secret_name
  kube_dashboard_token_secret_name = var.kube_dashboard_token_secret_name
  ami                              = local.ami_id
  cp_instance_type                 = var.cp_instance_type
  cp_azs                           = local.cp_azs
  cp_vpc_security_group_ids        = [module.cp_sg.id]
  cp_key_pair_name                 = module.cp_ec2_key_pair.key_pair_name
  cp_private_subnets               = local.cp_private_subnet
  cp_iam_instance_profile_name     = module.cp_iam_role.iam_instance_profile_name

  wn_instance_type             = var.wn_instance_type
  wn_iam_instance_profile_name = module.wn_iam_role.iam_instance_profile_name
  wn_key_pair_name             = module.wn_ec2_key_pair.key_pair_name
  wn_vpc_security_group_ids    = [module.wn_sg.id]
  wn_private_subnets           = local.wn_private_subnet
  sns_protocol                 = var.sns_protocol
  sns_endpoint                 = var.sns_endpoint
  tags                         = local.tags

  # Ensure EC2 instance creation waits for the probe to succeed
  depends_on = [
    null_resource.check_gateways
  ]
}

################## Bastion ######################
module "bastion" {
  source                  = "./modules/bastion"
  env                     = var.env
  region                  = var.region
  prefix                  = var.prefix
  kube_config_secret_name = module.kube_cluster.kube_config_secret_name
  azs                     = local.azs
  vpc_id                  = module.vpc.vpc_id
  ami                     = local.ami_id
  public_subnet_id        = element(module.vpc.public_subnets, length(module.vpc.public_subnets) - 1)
  tags                    = local.tags

  # Ensure EC2 instance creation waits for the probe to succeed
  depends_on = [
    null_resource.check_gateways,
    module.kube_cluster
  ]
}

####### Bastion Security Geoup Attachments ######
resource "aws_vpc_security_group_ingress_rule" "cp_allow_api_from_bastion" {
  security_group_id            = module.cp_sg.id
  from_port                    = 6443
  to_port                      = 6443
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.bastion.sg_id
}

################# Route 53 ######################
module "sub_domain_cert" {
  source       = "./modules/sub-domain-cert"
  country      = var.country
  state        = var.state
  locality     = var.locality
  organization = var.organization
  common_name  = var.common_name
  tags         = local.tags
}

################## Secrets ######################

module "secret_sub_domain_cert_body" {
  source       = "./modules/secret-manager"
  env          = var.env
  region       = var.region
  prefix       = var.prefix
  secret_name  = var.sub_domain_cert_body_secret_name
  secret_value = module.sub_domain_cert.certificate_body
  tags         = local.tags
}

module "secret_sub_domain_cert_key" {
  source       = "./modules/secret-manager"
  env          = var.env
  region       = var.region
  prefix       = var.prefix
  secret_name  = var.sub_domain_cert_key_secret_name
  secret_value = module.sub_domain_cert.certificate_key
  tags         = local.tags
}

################### ECR #######################

module "ecr_and_policy" {
  source               = "./modules/ecr-and-policy"
  env                  = var.env
  region               = var.region
  prefix               = var.prefix
  ecr_name             = var.ecr_name
  image_tag_mutability = var.image_tag_mutability
  policy               = jsonencode(var.ecr_lifecycle_policy)
  tags                 = local.tags
}

############### S3 Ansible SSM ###################

# module "s3_ansible_ssm" {
#   source = "./modules/s3-ansible-ssm"
#   env    = var.env
#   region = var.region
#   prefix = var.prefix
#   tags   = local.tags
# }