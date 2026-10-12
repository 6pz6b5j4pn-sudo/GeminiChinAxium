variable "event_service_name" {
  description = "Name prefix for the event service resources."
  type        = string
  default     = "event-service"
}

variable "event_service_image_tag" {
  description = "Image tag in the ECR repository to deploy."
  type        = string
  default     = "latest"
}

variable "event_service_port" {
  description = "Container port; passed to the service as PORT."
  type        = number
  default     = 8080
}

variable "event_service_env" {
  description = "Value for the service ENV variable."
  type        = string
  default     = "dev"
}

variable "event_service_processing_delay_ms" {
  description = "Value for the service PROCESSING_DELAY_MS variable."
  type        = number
  default     = 1000
}

variable "event_service_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "event_service_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "event_service_desired_count" {
  description = "Number of tasks to run. The service keeps events in memory, so more than 1 gives inconsistent data."
  type        = number
  default     = 1
}

variable "event_service_log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 14
}
