locals {

  role_replication_name = var.role_replication_name == "default" ? (
    format("%s-repl", local.bucket_name)
  ) : var.role_replication_name

}

resource "aws_iam_role" "replication" {
  count = var.s3_replication_enabled ? 1 : 0

  name               = local.role_replication_name
  assume_role_policy = data.aws_iam_policy_document.replication_sts[0].json

  tags = merge(
    var.labels,
    var.tags,
    { Name = local.role_replication_name }
  )
}

data "aws_iam_policy_document" "replication_sts" {
  count = var.s3_replication_enabled ? 1 : 0

  statement {
    sid    = "AllowPrimaryToAssumeServiceRole"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "replication" {
  count = var.s3_replication_enabled ? 1 : 0

  name   = local.role_replication_name
  policy = data.aws_iam_policy_document.replication[0].json

  tags = merge(
    var.labels,
    var.tags,
    { Name = local.role_replication_name }
  )
}

data "aws_iam_policy_document" "replication" {
  count = var.s3_replication_enabled ? 1 : 0

  statement {
    sid    = "AllowPrimaryToGetReplicationConfiguration"
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.default.arn,
      "${aws_s3_bucket.default.arn}/*"
    ]
  }

  statement {
    sid    = "AllowPrimaryToReplicate"
    effect = "Allow"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:GetObjectVersionTagging",
      "s3:ObjectOwnerOverrideToBucketOwner"
    ]

    resources = toset(concat(
      try(length(var.s3_replica_bucket_arn), 0) > 0 ? ["${var.s3_replica_bucket_arn}/*"] : [],
      [for rule in var.s3_replication_rules : "${rule.destination_bucket}/*" if try(length(rule.destination_bucket), 0) > 0],
    ))
  }
}

resource "aws_iam_role_policy_attachment" "replication" {
  count      = var.s3_replication_enabled ? 1 : 0
  role       = aws_iam_role.replication[0].name
  policy_arn = aws_iam_policy.replication[0].arn
}

resource "aws_s3_bucket_replication_configuration" "default" {
  count = var.s3_replication_enabled ? 1 : 0

  bucket = join("", aws_s3_bucket.default.*.id)
  role   = aws_iam_role.replication[0].arn

  dynamic "rule" {
    for_each = var.s3_replication_rules == null ? [] : var.s3_replication_rules

    content {
      id       = rule.value.id
      priority = try(rule.value.priority, 0)

      status = try(rule.value.status, null)

      # This is only relevant when "filter" is used
      delete_marker_replication {
        status = try(rule.value.delete_marker_replication_status, "Disabled")
      }

      destination {
        # Prefer newer system of specifying bucket in rule, but maintain backward compatibility with
        # s3_replica_bucket_arn to specify single destination for all rules
        bucket        = try(length(rule.value.destination_bucket), 0) > 0 ? rule.value.destination_bucket : var.s3_replica_bucket_arn
        storage_class = try(rule.value.destination.storage_class, "STANDARD")

        dynamic "encryption_configuration" {
          for_each = try(rule.value.destination.replica_kms_key_id, null) != null ? [1] : []

          content {
            replica_kms_key_id = try(rule.value.destination.replica_kms_key_id, null)
          }
        }

        account = try(rule.value.destination.account, null)

        # https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-walkthrough-5.html
        dynamic "metrics" {
          for_each = try(rule.value.destination.metrics.status, "") == "Enabled" ? [1] : []

          content {
            status = "Enabled"
            event_threshold {
              # Minutes can only have 15 as a valid value.
              minutes = 15
            }
          }
        }

        # This block is required when replication metrics are enabled.
        dynamic "replication_time" {
          for_each = try(rule.value.destination.metrics.status, "") == "Enabled" ? [1] : []

          content {
            status = "Enabled"
            time {
              # Minutes can only have 15 as a valid value.
              minutes = 15
            }
          }
        }

        dynamic "access_control_translation" {
          for_each = try(rule.value.destination.access_control_translation.owner, null) == null ? [] : [rule.value.destination.access_control_translation.owner]

          content {
            owner = access_control_translation.value
          }
        }
      }

      # Replication to multiple destination buckets requires that priority is specified in the rules object.
      # If the corresponding rule requires no filter, an empty configuration block filter {} must be specified.
      # See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
      dynamic "filter" {
        for_each = try(rule.value.filter, null) == null ? [{ prefix = null, tags = {} }] : [rule.value.filter]

        content {
          prefix = try(filter.value.prefix, try(rule.value.prefix, null))
          dynamic "tag" {
            for_each = try(filter.value.tags, {})

            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }
    }
  }

  depends_on = [
    # versioning must be set before replication
    aws_s3_bucket_versioning.default
  ]
}