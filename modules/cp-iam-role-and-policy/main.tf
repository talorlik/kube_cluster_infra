locals {
  iam_role_name                = "${var.prefix}-${var.region}-${var.iam_role_name}-${var.env}"
  iam_role_secret_policy_name  = "${var.prefix}-${var.region}-secret-${var.iam_role_policy_name}-${var.env}"
  iam_role_route53_policy_name = "${var.prefix}-${var.region}-route53-${var.iam_role_policy_name}-${var.env}"
  iam_instance_profile_name    = "${var.prefix}-${var.region}-${var.iam_instance_profile_name}-${var.env}"
}

resource "aws_iam_role" "iam_role" {
  name                  = local.iam_role_name
  force_detach_policies = false
  max_session_duration  = 3600
  path                  = "/"
  assume_role_policy    = jsonencode(var.assume_role_policy)

  tags = merge(
    {
      Name = "${local.iam_role_name}"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "iam-role-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.iam_role.name
}

resource "aws_iam_role_policy_attachment" "iam-role-AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.iam_role.name
}

resource "aws_iam_role_policy_attachment" "iam-role-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.iam_role.name
}

resource "aws_iam_role_policy_attachment" "iam-role-AmazonSSMManagedInstanceCore" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.iam_role.name
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
  policy_arn = aws_iam_policy.iam_create_secret_policy.arn
  role       = aws_iam_role.iam_role.name
}

resource "aws_iam_policy" "iam_get_and_create_route53_policy" {
  name = local.iam_role_route53_policy_name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "GetAndCreateRoute53"
        Effect = "Allow",
        Action = [
          "route53:ListHostedZones",
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
          "route53:ChangeResourceRecordSets"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_route53_policy" {
  policy_arn = aws_iam_policy.iam_get_and_create_route53_policy.arn
  role       = aws_iam_role.iam_role.name
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = local.iam_instance_profile_name
  role = aws_iam_role.iam_role.name
}
