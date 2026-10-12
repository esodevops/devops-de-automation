variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "The project name"
  type        = string
  default     = "dml-temperature-analysis"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,43}[a-z0-9]$", var.project_name))
    error_message = "Use 3–45 lowercase letters, digits, or hyphens, starting and ending with a letter or digit."
  }
}

variable "use_existing_bucket" {
  description = "Set to true to use an existing S3 bucket instead of creating a new one"
  type        = bool
  default     = false
}

variable "existing_bucket_name" {
  description = "The name of the existing S3 bucket"
  type        = string
  default     = "dml-temperature-analysis-raw-data"
}

variable "force_destroy" {
  description = "Allow Terraform to delete a non-empty bucket, including all object versions"
  type        = bool
  default     = false
}
