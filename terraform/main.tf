data "aws_s3_bucket" "existing" {
  count  = var.use_existing_bucket ? 1 : 0
  bucket = var.existing_bucket_name
}

locals {
  bucket_name = var.use_existing_bucket ? data.aws_s3_bucket.existing[0].id : aws_s3_bucket.raw_data[0].id

  temperature_file = "${path.module}/../data/temperature_data.csv"
}

resource "aws_s3_bucket" "raw_data" {
  count = var.use_existing_bucket ? 0 : 1

  bucket        = "${var.project_name}-raw-data"
  force_destroy = var.force_destroy

  tags = {
    Name        = "${var.project_name}-raw-data"
    Environment = "dev"
  }
}

resource "aws_s3_bucket_versioning" "raw_data" {
  count  = var.use_existing_bucket ? 0 : 1
  bucket = aws_s3_bucket.raw_data[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw_data" {
  count  = var.use_existing_bucket ? 0 : 1
  bucket = aws_s3_bucket.raw_data[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "data_directory" {
  bucket  = local.bucket_name
  key     = "data/"
  content = ""

  depends_on = [
    aws_s3_bucket_server_side_encryption_configuration.raw_data,
    aws_s3_bucket_versioning.raw_data,
  ]
}

resource "aws_s3_object" "temperature_data" {
  bucket       = local.bucket_name
  key          = "data/temperature_data.csv"
  source       = local.temperature_file
  source_hash  = filemd5(local.temperature_file)
  content_type = "text/csv"

  depends_on = [
    aws_s3_bucket_server_side_encryption_configuration.raw_data,
    aws_s3_bucket_versioning.raw_data,
  ]
}

# AWS Glue IAM role

resource "aws_iam_role" "glue_role" {
  name                  = "AWSGlueServiceRole-${var.project_name}"
  force_detach_policies = true

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_role" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_s3_access" {
  name = "${var.project_name}-raw-data-read"
  role = aws_iam_role.glue_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${local.bucket_name}"
        Condition = {
          StringLike = {
            "s3:prefix" = ["data", "data/", "data/*"]
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${local.bucket_name}/data/*"
      }
    ]
  })
}

# Glue database

resource "aws_glue_catalog_database" "main" {
  name = replace("${var.project_name}_temperature_analysis", "-", "_")
}

# Glue crawler

resource "aws_glue_crawler" "main" {
  name          = "${var.project_name}-crawler"
  database_name = aws_glue_catalog_database.main.name
  role          = aws_iam_role.glue_role.arn
  schedule      = "cron(0 1 * * ? *)"

  s3_target {
    path = "s3://${local.bucket_name}/data/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }

  lineage_configuration {
    crawler_lineage_settings = "DISABLE"
  }

  lake_formation_configuration {
    use_lake_formation_credentials = false
  }

  configuration = jsonencode({
    Version = 1.0
    Grouping = {
      TableLevelConfiguration = 3
    }
  })

  depends_on = [
    aws_s3_object.data_directory,
    aws_s3_object.temperature_data,
    aws_iam_role_policy_attachment.glue_service_role,
    aws_iam_role_policy.glue_s3_access,
  ]
}

resource "aws_s3_bucket_public_access_block" "raw_data" {
  count  = var.use_existing_bucket ? 0 : 1
  bucket = aws_s3_bucket.raw_data[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
