# Mock providers exercise both deployment modes without AWS credentials or writes.
mock_provider "aws" {}

run "new_bucket" {
  command = plan

  variables {
    project_name = "test-temperature"
  }

  assert {
    condition     = length(aws_s3_bucket.raw_data) == 1 && length(data.aws_s3_bucket.existing) == 0
    error_message = "New-bucket mode must create exactly one bucket."
  }
  assert {
    condition     = !aws_s3_bucket.raw_data[0].force_destroy
    error_message = "Non-empty buckets must be protected by default."
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.raw_data[0].block_public_policy && aws_s3_bucket_public_access_block.raw_data[0].restrict_public_buckets
    error_message = "Created buckets must block public access."
  }
  assert {
    condition     = aws_glue_crawler.main.name == "test-temperature-crawler" && aws_iam_role.glue_role.name == "AWSGlueServiceRole-test-temperature"
    error_message = "Crawler and role names must honor the project name."
  }
  assert {
    condition     = aws_glue_catalog_database.main.name == "test_temperature_temperature_analysis"
    error_message = "Catalog database names must normalize hyphens."
  }
  assert {
    condition     = aws_s3_object.temperature_data.key == "data/temperature_data.csv" && aws_s3_object.temperature_data.content_type == "text/csv"
    error_message = "The CSV must be uploaded under the crawler prefix."
  }
}

run "existing_bucket" {
  command = plan

  variables {
    use_existing_bucket  = true
    existing_bucket_name = "existing-temperature-bucket"
  }

  override_data {
    target = data.aws_s3_bucket.existing[0]
    values = {
      id = "existing-temperature-bucket"
    }
  }

  assert {
    condition     = length(aws_s3_bucket.raw_data) == 0 && length(aws_s3_bucket_versioning.raw_data) == 0 && length(aws_s3_bucket_server_side_encryption_configuration.raw_data) == 0 && length(aws_s3_bucket_public_access_block.raw_data) == 0
    error_message = "Existing-bucket mode must not manage bucket configuration."
  }
  assert {
    condition     = output.raw_bucket_name == "existing-temperature-bucket" && aws_s3_object.temperature_data.bucket == "existing-temperature-bucket"
    error_message = "Existing-bucket mode must upload to the supplied bucket."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.glue_s3_access.policy).Statement[1].Resource == "arn:aws:s3:::existing-temperature-bucket/data/*"
    error_message = "Crawler object access must be scoped to the selected data prefix."
  }
}

run "invalid_project_name" {
  command = plan
  variables {
    project_name = "UPPERCASE-not-valid"
  }
  expect_failures = [var.project_name]
}

run "iam_name_length_limit" {
  command = plan
  variables {
    project_name = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrst"
  }
  expect_failures = [var.project_name]
}
