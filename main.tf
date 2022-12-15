locals {

  labels = var.labels

  bucket_name = var.bucket_name == "default" ? (
    "${local.labels.prefix}-${local.labels.stack}-${local.labels.component}-${data.aws_region.current.name}-${var.account_id}-${local.labels.env}"
  ) : var.bucket_name

  public_access_block_enabled = var.block_public_acls || var.block_public_policy || var.ignore_public_acls || var.restrict_public_buckets

}

data "aws_region" "current" {}

resource "aws_s3_bucket" "default" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = merge(local.labels, { "Name" : local.bucket_name })
}

resource "aws_s3_bucket_acl" "default" {
  bucket = aws_s3_bucket.default.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.default.id

  rule {
    bucket_key_enabled = var.bucket_key_enabled

    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.kms_master_key_arn
    }
  }

}

resource "aws_s3_bucket_versioning" "default" {
  count  = var.versioning_enabled ? 1 : 0
  bucket = aws_s3_bucket.default.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "default" {
  count  = local.public_access_block_enabled ? 1 : 0
  bucket = aws_s3_bucket.default.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}


resource "aws_s3_bucket_logging" "default" {
  count  = var.logging != null ? 1 : 0
  bucket = join("", aws_s3_bucket.default.*.id)

  target_bucket = var.logging["bucket_name"]
  target_prefix = var.logging["prefix"]
}