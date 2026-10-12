variable "aws_region" {
  description = "AWS region where the application is deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used for the Lambda function and API."
  type        = string
  default     = "laura-ipsum-python"
}
