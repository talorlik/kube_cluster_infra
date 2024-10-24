locals {
  iam_role_name               = "${var.prefix}-${var.region}-bastion-iam-role-${var.env}"
  iam_ssm_policy_name         = "${var.prefix}-${var.region}-bastion-ssm-iam-policy-${var.env}"
  iam_role_secret_policy_name = "${var.prefix}-${var.region}-bastion-secret-iam-policy-${var.env}"
  iam_role_general_name       = "${var.prefix}-${var.region}-bastion-general-iam-policy-${var.env}"
  iam_profile_name            = "${var.prefix}-${var.region}-bastion-instance-profile-${var.env}"
  sg_name                     = "${var.prefix}-${var.region}-bastion-sg-${var.env}"
  key_name                    = "${var.prefix}-${var.region}-bastion-key-pair-${var.env}"
  ec2_instance_name           = "${var.prefix}-${var.region}-bastion-ec2-${var.env}"
  az                          = element(var.azs, length(var.azs) - 1)
  user_data = templatefile("${path.module}/deploy.sh.tftpl", {
    aws_region              = var.region
    kube_config_secret_name = var.kube_config_secret_name
  })
}

############## IAM Role + Policy + Profile ################
resource "aws_iam_role" "bastion_role" {
  name = local.iam_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name = "${local.iam_role_name}"
    },
    var.tags
  )
}

resource "aws_iam_policy" "ssm_policy" {
  name = local.iam_ssm_policy_name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:StartSession",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus",
          "ssm:DescribeInstanceInformation",
          "ssm:TerminateSession"
        ],
        Resource = [
          "arn:aws:ssm:*:*:document/SSM-SessionManagerRunShell",
          "arn:aws:ssm:*:*:document/AWS-StartSSHSession",
          "arn:aws:ec2:*:*:instance/*",
          "arn:aws:ssm:*:*:session/*"
        ]
      },
      {
        Effect   = "Allow",
        Action   = "ssmmessages:*",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ssm_policy" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

resource "aws_iam_policy" "iam_create_secret_policy" {
  name = local.iam_role_secret_policy_name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "CreateAndReadOnlySecret",
        Effect = "Allow",
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:UpdateSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:TagResource"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_secret_policy" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.iam_create_secret_policy.arn
}

resource "aws_iam_policy" "ec2_general_policy" {
  name = local.iam_role_general_name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "DescribeLB",
        Action   = "elasticloadbalancing:DescribeLoadBalancers",
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Sid      = "ECRLogin",
        Effect   = "Allow",
        Action   = "ecr:GetAuthorizationToken",
        Resource = "*"
      },
      {
        Sid      = "UpdateRoute53",
        Effect   = "Allow",
        Action   = "route53:ChangeResourceRecordSets",
        Resource = "*"
      },
      {
        Sid    = "GetAndListRoute53",
        Effect = "Allow",
        Action = [
          "route53:GetChange",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListHostedZonesByName"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_general_policy_to_ec2" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = aws_iam_policy.ec2_general_policy.arn
}

resource "aws_iam_instance_profile" "bastion_profile" {
  name = local.iam_profile_name
  role = aws_iam_role.bastion_role.name
}

################# Bastion Security Group #######################
resource "aws_security_group" "sg" {
  name   = local.sg_name
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${local.sg_name}"
    },
    var.tags
  )
}

################## Bastion Key Pair ########################
resource "tls_private_key" "bastion_tls_private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key" {
  content  = tls_private_key.bastion_tls_private_key.private_key_pem
  filename = "${path.module}/${var.region}/${var.env}/${local.key_name}.pem"
}

resource "local_file" "public_key" {
  content  = tls_private_key.bastion_tls_private_key.public_key_pem
  filename = "${path.module}/${var.region}/${var.env}/${local.key_name}.pub"
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = local.key_name
  public_key = tls_private_key.bastion_tls_private_key.public_key_openssh
  tags       = var.tags
}

##################### Bastion EC2 ###########################
resource "aws_instance" "cp_ec2" {
  ami                         = var.ami
  instance_type               = "t3.micro"
  availability_zone           = local.az
  vpc_security_group_ids      = [aws_security_group.sg.id]
  key_name                    = local.key_name
  subnet_id                   = var.public_subnet_id
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name
  user_data                   = base64encode(local.user_data)
  associate_public_ip_address = true
  ebs_optimized               = true

  root_block_device {
    iops        = 300
    volume_size = 20
    volume_type = "gp3"
  }

  lifecycle {
    ignore_changes = [
      root_block_device,
      ebs_block_device,
    ]
  }

  tags = merge(
    {
      Name = "${local.ec2_instance_name}"
      SSH  = "bastion"
    },
    var.tags
  )
}