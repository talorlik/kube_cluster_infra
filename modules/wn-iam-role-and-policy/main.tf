locals {
  iam_role_name             = "${var.prefix}-${var.region}-${var.iam_role_name}-${var.env}"
  iam_role_policy_name      = "${var.prefix}-${var.region}-${var.iam_role_policy_name}-${var.env}"
  iam_instance_profile_name = "${var.prefix}-${var.region}-${var.iam_instance_profile_name}-${var.env}"
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

resource "aws_iam_role_policy_attachment" "iam-role-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
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

resource "aws_iam_role_policy_attachment" "iam-role-CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.iam_role.name
}

resource "aws_iam_policy" "iam_read_secret_policy" {
  name = local.iam_role_policy_name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "ReadSpecificSecret",
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  policy_arn = aws_iam_policy.iam_read_secret_policy.arn
  role       = aws_iam_role.iam_role.name
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = local.iam_instance_profile_name
  role = aws_iam_role.iam_role.name
}
