output "application_url" {
  description = "Public URL for the deployed Python Lambda application."
  value       = aws_apigatewayv2_api.app.api_endpoint
}
