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
  vpc_name                     = "${var.prefix}-${var.region}-vpc-${var.env}"
  igw_name                     = "${var.prefix}-${var.region}-igw-${var.env}"
  cluster_name                 = "${var.prefix}-${var.region}-${var.cluster_name}-${var.env}"
  cp_iam_role_name             = "${var.prefix}-${var.region}-${var.cp_iam_role_name}-${var.env}"
  wn_iam_role_name             = "${var.prefix}-${var.region}-${var.wn_iam_role_name}-${var.env}"
  cp_iam_role_policy_name      = "${var.prefix}-${var.region}-${var.cp_iam_role_policy_name}-${var.env}"
  wn_iam_role_policy_name      = "${var.prefix}-${var.region}-${var.wn_iam_role_policy_name}-${var.env}"
  cp_iam_instance_profile_name = "${var.prefix}-${var.region}-${var.cp_iam_instance_profile_name}-${var.env}"
  wn_iam_instance_profile_name = "${var.prefix}-${var.region}-${var.wn_iam_instance_profile_name}-${var.env}"
  cp_sg_name                   = "${var.prefix}-${var.region}-${var.cp_sg_name}-${var.env}"
  wn_sg_name                   = "${var.prefix}-${var.region}-${var.wn_sg_name}-${var.env}"
  alb_sg_name                  = "${var.prefix}-${var.region}-${var.alb_sg_name}-${var.env}"
  azs                          = slice(data.aws_availability_zones.available.names, 0, 3)
  cp_azs                       = slice(local.azs, 0, 1)
  wn_azs                       = slice(local.azs, 1, 3)
  ami_id                       = module.ubuntu_24_04_latest.ami_id
  tags = {
    Env       = var.env
    Terraform = true
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
    "kubernetes.io/role/alb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
  igw_tags = {
    Name = local.igw_name
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
  tags = local.tags
}

################## Control Plane IAM Role ######################

module "cp_iam_role" {
  source = "./modules/cp-iam-role-and-policy"

  env                       = var.env
  region                    = var.region
  prefix                    = var.prefix
  iam_role_name             = local.cp_iam_role_name
  assume_role_policy        = var.cp_iam_assume_role_policy
  iam_role_policy_name      = local.cp_iam_role_policy_name
  iam_instance_profile_name = local.cp_iam_instance_profile_name
  tags                      = local.tags
}

################## Worker Nodes IAM Role ######################

module "wn_iam_role" {
  source = "./modules/wn-iam-role-and-policy"

  env                       = var.env
  region                    = var.region
  prefix                    = var.prefix
  iam_role_name             = local.wn_iam_role_name
  assume_role_policy        = var.wn_iam_assume_role_policy
  iam_role_policy_name      = local.wn_iam_role_policy_name
  iam_instance_profile_name = local.wn_iam_instance_profile_name
  tags                      = local.tags
}

############# Bastion SSM Policy for cluster machines ##################
resource "aws_iam_policy" "iam_ssm_policy" {
  name = "${var.prefix}-${var.region}-cluster-ssm-iam-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:DescribeAssociation",
          "ssm:GetDeployablePatchSnapshotForInstance",
          "ssm:GetDocument",
          "ssm:DescribeDocument",
          "ssm:GetManifest",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:ListAssociations",
          "ssm:ListInstanceAssociations",
          "ssm:PutInventory",
          "ssm:PutComplianceItems",
          "ssm:PutConfigurePackageResult",
          "ssm:UpdateAssociationStatus",
          "ssm:UpdateInstanceAssociationStatus",
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cp_attach_ssm_policy" {
  policy_arn = aws_iam_policy.iam_ssm_policy.arn
  role       = module.cp_iam_role.iam_role_name
}

resource "aws_iam_role_policy_attachment" "wn_attach_ssm_policy" {
  policy_arn = aws_iam_policy.iam_ssm_policy.arn
  role       = module.wn_iam_role.iam_role_name
}

############# Control Plane Security Group ##################
module "cp_sg" {
  source = "./modules/security-group"

  env           = var.env
  region        = var.region
  prefix        = var.prefix
  name          = local.cp_sg_name
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
  name          = local.wn_sg_name
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
resource "aws_vpc_security_group_ingress_rule" "control_plane_allow_all_from_worker_nodes_tcp" {
  security_group_id            = module.cp_sg.id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.wn_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "control_plane_allow_all_from_worker_nodes_udp" {
  security_group_id            = module.cp_sg.id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "udp"
  referenced_security_group_id = module.wn_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "worker_nodes_allow_all_from_control_plane_tcp" {
  security_group_id            = module.wn_sg.id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.cp_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "worker_nodes_allow_all_from_control_plane_udp" {
  security_group_id            = module.wn_sg.id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "udp"
  referenced_security_group_id = module.cp_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "worker_nodes_allow_all_from_worker_nodes_tcp" {
  security_group_id            = module.wn_sg.id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.wn_sg.id
}

resource "aws_vpc_security_group_ingress_rule" "worker_nodes_allow_all_from_worker_nodes_udp" {
  security_group_id            = module.wn_sg.id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "udp"
  referenced_security_group_id = module.wn_sg.id
}

################ ALB Security Group #####################
module "alb_sg" {
  source = "./modules/security-group"

  env           = var.env
  region        = var.region
  prefix        = var.prefix
  name          = local.alb_sg_name
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
  source                       = "./modules/kube-cluster"
  env                          = var.env
  region                       = var.region
  prefix                       = var.prefix
  k8s_version                  = var.k8s_version
  cluster_name                 = local.cluster_name
  ami                          = local.ami_id
  cp_instance_type             = var.cp_instance_type
  cp_azs                       = local.cp_azs
  cp_vpc_security_group_ids    = [module.cp_sg.id]
  cp_key_pair_name             = module.cp_ec2_key_pair.key_pair_name
  cp_private_subnets           = local.cp_private_subnet
  cp_iam_instance_profile_name = module.cp_iam_role.iam_instance_profile_name

  wn_instance_type             = var.wn_instance_type
  wn_iam_instance_profile_name = module.wn_iam_role.iam_instance_profile_name
  wn_key_pair_name             = module.wn_ec2_key_pair.key_pair_name
  wn_vpc_security_group_ids    = [module.wn_sg.id]
  wn_private_subnets           = local.wn_private_subnet
  sns_protocol                 = var.sns_protocol
  sns_endpoint                 = var.sns_endpoint
  tags                         = local.tags
}

################## Bastion ######################
module "bastion" {
  source           = "./modules/bastion"
  env              = var.env
  region           = var.region
  prefix           = var.prefix
  azs              = local.azs
  vpc_id           = module.vpc.vpc_id
  ami              = local.ami_id
  public_subnet_id = element(module.vpc.public_subnets, length(module.vpc.public_subnets) - 1)
  tags             = local.tags
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

module "secret_sub_domain_cert" {
  source       = "./modules/secret-manager"
  env          = var.env
  region       = var.region
  prefix       = var.prefix
  secret_name  = var.domain_certificate_name
  secret_value = module.sub_domain_cert.certificate_body
  tags         = local.tags
}

################### ECR #######################

module "ecr_and_policy" {
  source = "./modules/ecr-and-policy"

  env                  = var.env
  region               = var.region
  prefix               = var.prefix
  ecr_name             = var.ecr_name
  image_tag_mutability = var.image_tag_mutability
  policy               = jsonencode(var.ecr_lifecycle_policy)
  tags                 = local.tags
}