# aws-s3-bucket

Terraform module to create S3 bucket. It has support for versioning, lifecycles, replication, encryption, bucket object policies.


```

terrafrom config example:

```
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
```
more info see [examples/test](examples/test)


terraform run example
```
cd examples/test
terraform init
terraform plan
``` 

Terraform versions tested
- 1.1.8
