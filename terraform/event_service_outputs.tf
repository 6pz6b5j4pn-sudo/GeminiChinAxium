output "event_service_url" {
  description = "Public URL of the event service ALB."
  value       = "http://${aws_lb.event_service.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository to push the event service image to."
  value       = aws_ecr_repository.event_service.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster running the event service."
  value       = aws_ecs_cluster.event_service.name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.event_service.name
}

output "event_service_log_group" {
  description = "CloudWatch log group for the event service."
  value       = aws_cloudwatch_log_group.event_service.name
}
