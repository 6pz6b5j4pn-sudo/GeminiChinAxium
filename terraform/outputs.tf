output "application_url" {
  description = "Public URL that displays the deployed Python source."
  value       = aws_apigatewayv2_api.app.api_endpoint
}
