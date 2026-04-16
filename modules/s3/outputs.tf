output "cicd_bucket_name" {
  description = "Name of the CI/CD artifacts bucket"
  value       = aws_s3_bucket.cicd_bucket.id
}

output "cicd_bucket_arn" {
  description = "ARN of the CI/CD artifacts bucket"
  value       = aws_s3_bucket.cicd_bucket.arn
}

output "cicd_bucket_region" {
  description = "Region of the CI/CD artifacts bucket"
  value       = aws_s3_bucket.cicd_bucket.region
}

output "cicd_logs_bucket_name" {
  description = "Name of the CI/CD logs bucket"
  value       = aws_s3_bucket.cicd_logs_bucket.id
}

output "cicd_logs_bucket_arn" {
  description = "ARN of the CI/CD logs bucket"
  value       = aws_s3_bucket.cicd_logs_bucket.arn
}
