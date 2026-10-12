output "raw_bucket_name" {
  description = "Name of the raw data S3 bucket"
  value       = local.bucket_name
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = local.bucket_name
}
output "crawler_name" {
  description = "Glue crawler name for manual runs and status checks"
  value       = aws_glue_crawler.main.name
}

output "catalog_database_name" {
  description = "Glue Data Catalog database populated by the crawler"
  value       = aws_glue_catalog_database.main.name
}
