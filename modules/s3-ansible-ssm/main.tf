locals {
  name = "${var.prefix}-${var.region}-s3-ansible-ssm-${var.env}"
}

resource "aws_s3_bucket" "ansible_ssm" {
  bucket        = local.name
  force_destroy = true

  lifecycle {
    prevent_destroy = false
  }

  tags = merge(
    {
      Name = local.name
    },
    var.tags
  )
}

resource "aws_s3_bucket_acl" "ansible_ssm_acl" {
  bucket     = aws_s3_bucket.ansible_ssm.bucket
  acl        = "public-read-write"
  depends_on = [aws_s3_bucket_ownership_controls.ansible_ssm_acl_ownership]
}

# Resource to avoid error "AccessControlListNotSupported: The bucket does not allow ACLs"
resource "aws_s3_bucket_ownership_controls" "ansible_ssm_acl_ownership" {
  bucket = aws_s3_bucket.ansible_ssm.bucket
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_versioning" "ansible_ssm_versioning" {
  bucket = aws_s3_bucket.ansible_ssm.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "ansible_ssm_public_access_block" {
  bucket = aws_s3_bucket.ansible_ssm.bucket

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "ansible_ssm_policy" {
  bucket     = aws_s3_bucket.ansible_ssm.bucket
  depends_on = [aws_s3_bucket.ansible_ssm]
  policy     = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
	    {
			"Sid": "ListGetPutDeleteBucketContents",
			"Effect": "Allow",
			"Action": [
                "s3:ListBucket",
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:GetBucketLocation"
            ],
			"Principal": "*",
			"Resource": [
                "arn:aws:s3:::${aws_s3_bucket.ansible_ssm.bucket}",
                "arn:aws:s3:::${aws_s3_bucket.ansible_ssm.bucket}/*"
            ]
		}
	]
}
EOF
}

# Add bucket encryption to hide sensitive state data
resource "aws_s3_bucket_server_side_encryption_configuration" "ansible_ssm_encryption" {
  bucket = aws_s3_bucket.ansible_ssm.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
