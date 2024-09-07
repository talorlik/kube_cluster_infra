### General ###
env            = "prod"
prefix         = "talo-tf"
resource_alias = "talo"
### VPC ###
vpc_cidr = "10.0.0.0/16"
### Control Plane IAM Role ###
cp_iam_role_name             = "cp-role"
cp_iam_role_policy_name      = "cp-policy"
cp_iam_instance_profile_name = "cp-instance-profile"
cp_iam_assume_role_policy = {
  Version = "2012-10-17",
  Statement = [
    {
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }
  ]
}
### Worker Nodes IAM Role ###
wn_iam_role_name             = "wn-role"
wn_iam_role_policy_name      = "wn-policy"
wn_iam_instance_profile_name = "wn-instance-profile"
wn_iam_assume_role_policy = {
  Version = "2012-10-17",
  Statement = [
    {
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }
  ]
}
### Controle Plane Security Group ###
cp_sg_name = "cp-sg"
cp_sg_ingress_rules = [
  {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
  }
]
cp_sg_egress_rules = [
  {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
  }
]
### Worker Nodes Security Group ###
wn_sg_name = "wn-sg"
wn_sg_ingress_rules = [
  {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
  }
]
wn_sg_egress_rules = [
  {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = []
  }
]
### ALB Security Group ###
alb_sg_name = "alb-sg"
alb_sg_ingress_rules = [
  {
    from_port       = 8443
    to_port         = 8443
    protocol        = "tcp"
    cidr_blocks     = ["149.154.160.0/20"]
    security_groups = []
  },
  {
    from_port       = 8443
    to_port         = 8443
    protocol        = "tcp"
    cidr_blocks     = ["91.108.4.0/22"]
    security_groups = []
  }
]
### Kubernetes Cluster ###
k8s_version      = "v1.31"
cluster_name     = "kube-cluster"
cp_instance_type = "t3.medium"
wn_instance_type = "t3.medium"
sns_protocol     = "email"
sns_endpoint     = "talorlik@gmail.com"
### Secrets ###
sub_domain_cert_body_secret_name = "sub-domain/certificate-body/v2"
sub_domain_cert_key_secret_name  = "sub-domain/certificate-key/v2"
join_secret_name                 = "kubeadm/join-details/v2"
kube_config_secret_name          = "kube/config/v2"
kube_dashboard_token_secret_name = "kube/dashboard-token/v2"
### ECR ###
ecr_name             = "docker-images"
image_tag_mutability = "IMMUTABLE"
ecr_lifecycle_policy = {
  rules = [
    {
      rulePriority = 1
      description  = "Always keep at least the most recent image"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["yolo5-v2", "polybot-v2"]
        countType     = "imageCountMoreThan"
        countNumber   = 1
      }
      action = {
        type = "expire"
      }
    },
    {
      rulePriority = 2
      description  = "Keep only one untagged image, expire all others"
      selection = {
        tagStatus   = "untagged"
        countType   = "imageCountMoreThan"
        countNumber = 1
      }
      action = {
        type = "expire"
      }
    }
  ]
}