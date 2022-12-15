data "aws_iam_policy_document" "bucket_policy" {
  count = 1
  dynamic "statement" {

    for_each = var.privileged_principal_arns
    content {
      sid     = "AllowPrivilegedPrincipal[${statement.key}]" # add indices to Sid
      actions = var.privileged_principal_actions
      resources = distinct(flatten([
        "arn:aws:s3:::${join("", aws_s3_bucket.default.*.id)}",
        formatlist("arn:aws:s3:::${join("", aws_s3_bucket.default.*.id)}/%s*", values(statement.value)[0]),
      ]))
      principals {
        type        = "AWS"
        identifiers = [keys(statement.value)[0]]
      }
    }

  }
}


data "aws_iam_policy_document" "aggregated_policy" {
  count                     = 1
  source_policy_documents   = data.aws_iam_policy_document.bucket_policy.*.json
  override_policy_documents = var.source_policy_documents
}

resource "aws_s3_bucket_policy" "default" {
  count      = (length(var.privileged_principal_arns) > 0 || length(var.source_policy_documents) > 0) ? 1 : 0
  bucket     = aws_s3_bucket.default.id
  policy     = join("", data.aws_iam_policy_document.aggregated_policy.*.json)
  depends_on = [aws_s3_bucket_public_access_block.default]
}