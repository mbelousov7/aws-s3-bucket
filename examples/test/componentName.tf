#################################################  <ENV>.tfvars  #################################################
# in the examples for modules, variables are defined and set in the same file as the module definition.
# This is done to better understand the meaning of the variables.
# In a real environment, you should define variables in a variables.tf, the values of variables depending on the environment in the <ENV name>.tfvars
########################################################### environment variables ############################################################
variable "ENV" {
  type        = string
  description = "defines the name of the environment(dev, prod, etc). Should be defined as env variable, for example export TF_VAR_ENV=dev"
}

variable "prefix" {
  type    = string
  default = "myproject"
}

variable "stack" {
  default = "stackname"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "region_primary" {
  type    = string
  default = "us-east-1"
}

variable "region_secondary" {
  type    = string
  default = "eu-west-1"
}

# <ENV>.tfvars end
#################################################################################################################

#################################################  locals vars  #################################################
#if the value of a variable depends on the value of other variables, it should be defined in a locals block
locals {

  default_tags = {
    "service-name" = var.stack
  }

  labels = merge(
    { env = var.ENV },
    { prefix = var.prefix },
    { stack = var.stack }
  )

  force_destroy = true //change to true before delete not empty bucket

  logs_bucket                = "Enabled"
  data_bucket                = "Enabled"
  all_buckets_s3_replication = "Enabled"

  account_id     = "apt"
  logs_bucket_id = "bucket-logs"
  data_bucket_id = "bucket-data"

  logging = local.logs_bucket == "Enabled" ? {
    bucket_name = join("", module.logs_bucket.*.bucket_id)
    prefix      = "data-bucket-logs/"
  } : null

  logging_replica = local.logs_bucket == "Enabled" ? {
    bucket_name = join("", module.logs_bucket_replica.*.bucket_id)
    prefix      = "data-bucket-logs/"
  } : null

  data_bucket_s3_replication_rules = local.all_buckets_s3_replication == "Enabled" ? [
    {
      id                 = "replication"
      status             = "Enabled"
      destination_bucket = join("", module.data_bucket_replica.*.bucket_arn)
    }
  ] : null

  privileged_principal_actions = ["s3:GetObject"]
  privileged_principal_arns = [
    {
      "arn:aws:iam::01234567890:role/role-name-1" = [""]
    },
    {
      "arn:aws:iam::01234567890:role/role-name-2" = ["prefix1/", "prefix2/"]
    }
  ]

  lifecycle_configuration_rules_all = [
    {
      id     = "DeleteIncompleteMultipartUploads"
      status = "Enabled"
      abort_incomplete_multipart_upload = {
        days_after_initiation = 7
      }
    },
    {
      id     = "RemoveExpiredObjectDeleteMarkers"
      status = "Enabled"
      expiration = {
        days                         = 0
        expired_object_delete_marker = true
      }
  }]

  lifecycle_configuration_rules_logs = [{
    status = "Enabled"
    id     = "DeleteOldObjects"
    noncurrent_version_expiration = {
      noncurrent_days = 7
    }
    expiration = {
      days = 7
    }
  }]

}


#################################################  module config  #################################################
# In module parameters recommend use terraform variables, because:
# - values can be environment dependent
# - this ComponentName.tf file - is more for component logic description, not for values definition
# - it is better to store vars values in one or two places(<ENV>.tfvars file and variables.tf)

module "logs_bucket" {
  count                         = local.logs_bucket == "Enabled" ? 1 : 0
  source                        = "../.."
  force_destroy                 = local.force_destroy
  account_id                    = local.account_id
  lifecycle_configuration_rules = concat(local.lifecycle_configuration_rules_all, local.lifecycle_configuration_rules_logs)
  labels                        = merge(local.labels, { component = local.logs_bucket_id })
}

module "data_bucket" {
  count                         = local.data_bucket == "Enabled" ? 1 : 0
  source                        = "../.."
  s3_replication_enabled        = local.all_buckets_s3_replication == "Enabled" ? true : false
  s3_replication_rules          = local.data_bucket_s3_replication_rules
  logging                       = local.logging
  privileged_principal_arns     = local.privileged_principal_arns
  privileged_principal_actions  = local.privileged_principal_actions
  lifecycle_configuration_rules = local.lifecycle_configuration_rules_all

  force_destroy = local.force_destroy
  account_id    = local.account_id
  labels        = merge(local.labels, { component = local.data_bucket_id })

}

module "logs_bucket_replica" {
  count                         = local.all_buckets_s3_replication == "Enabled" && local.logs_bucket == "Enabled" ? 1 : 0
  providers                     = { aws = aws.secondary }
  source                        = "../.."
  force_destroy                 = local.force_destroy
  account_id                    = local.account_id
  lifecycle_configuration_rules = concat(local.lifecycle_configuration_rules_all, local.lifecycle_configuration_rules_logs)
  labels                        = merge(local.labels, { component = local.logs_bucket_id })
}


module "data_bucket_replica" {
  count                         = local.all_buckets_s3_replication == "Enabled" && local.data_bucket == "Enabled" ? 1 : 0
  providers                     = { aws = aws.secondary }
  source                        = "../.."
  logging                       = local.logging_replica
  privileged_principal_arns     = local.privileged_principal_arns
  privileged_principal_actions  = local.privileged_principal_actions
  lifecycle_configuration_rules = local.lifecycle_configuration_rules_all

  force_destroy = local.force_destroy
  account_id    = local.account_id
  labels        = merge(local.labels, { component = "${local.data_bucket_id}-replica" })
}
