variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "github_actions_role_arn" {
  description = "ARN of GitHub Actions IAM role"
  type        = string
}

variable "ec2_instance_role_arn" {
  description = "ARN of EC2 instance role for read access"
  type        = string
}
