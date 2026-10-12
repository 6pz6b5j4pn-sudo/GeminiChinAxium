variable "aws_region" {
  description = "AWS region where the application is deployed."
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Name used for the Lambda function and API."
  type        = string
  default     = "laura-ipsum-python"
}
