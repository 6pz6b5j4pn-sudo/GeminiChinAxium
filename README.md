# LauraIpsum

A Go event service ([app/](app)) with a Dockerfile and Terraform that deploy it
to AWS ECS Fargate behind an Application Load Balancer.

## Run locally

Requires Go 1.22+.

```bash
cd app
go run .
```

Open http://127.0.0.1:8080. Configure with environment variables `PORT`
(default `8080`), `ENV` (default `dev`) and `PROCESSING_DELAY_MS` (default
`1000`), e.g. `PORT=3000 PROCESSING_DELAY_MS=500 go run .`. API details are in
[app/README.md](app/README.md).

## Run with Docker

```bash
cd app
docker build -t event-service .
docker run --rm -p 8080:8080 -e ENV=staging -e PROCESSING_DELAY_MS=500 event-service
```

The image is multi-stage (Go build, then minimal Alpine), runs as a non-root
user, and has a `HEALTHCHECK` on `/health`.

## Deploy with Terraform

[terraform/](terraform) contains `main.tf` (resources), `variables.tf` and
`outputs.tf`. It creates an ECR repository, CloudWatch log group, ECS cluster,
Fargate task definition and service, and an ALB with an HTTP listener
forwarding to the service.

### Assumptions

- The AWS account has a **default VPC** with at least two public subnets in
  different availability zones; the ALB and tasks use all of them.
- Tasks get public IPs (no NAT gateway) so they can pull from ECR; their
  security group only allows traffic from the ALB.
- The ALB serves **plain HTTP on port 80**. For production add an ACM
  certificate and an HTTPS listener.
- **One task** (`event_service_desired_count = 1`): the service stores events
  in memory, so more tasks would each hold different data and lose it on restart.
- The image must exist in ECR before the service can start. The deploy
  workflow creates the repository, pushes the image tagged with the commit SHA,
  then applies Terraform with that tag. For manual use, apply
  `-target=aws_ecr_repository.event_service`, push the image, then apply the rest.
- The region defaults to `eu-west-2` (`aws_region`).
- Remote state is in S3 (see [terraform/backend.tf](terraform/backend.tf)); the
  bucket must already exist.

### Variables and outputs

| Variable | Default | Purpose |
|----------|---------|---------|
| `aws_region` | `eu-west-2` | AWS region |
| `event_service_name` | `event-service` | Name prefix for resources |
| `event_service_image_tag` | `latest` | ECR image tag to deploy |
| `event_service_port` | `8080` | Container port (`PORT`) |
| `event_service_env` | `dev` | `ENV` |
| `event_service_processing_delay_ms` | `1000` | `PROCESSING_DELAY_MS` |
| `event_service_cpu` / `event_service_memory` | `256` / `512` | Fargate size |
| `event_service_desired_count` | `1` | Number of tasks |
| `event_service_log_retention_days` | `14` | Log retention |

Outputs: `event_service_url`, `ecr_repository_url`, `ecs_cluster_name`,
`ecs_service_name`, `event_service_log_group`.

```bash
cd terraform
terraform init -backend-config='bucket=YOUR_TF_STATE_BUCKET' -backend-config='region=eu-west-2'
terraform apply -target=aws_ecr_repository.event_service
# build and push the image to the ecr_repository_url output, then:
terraform apply
terraform output -raw event_service_url
```

Run `terraform destroy` to remove everything.

## GitHub Actions

[deploy.yml](.github/workflows/deploy.yml) runs on pushes to `main`. Configure
these secrets in the `copilot` environment: `TF_STATE_BUCKET`,
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and optionally `AWS_REGION`. The
IAM user needs access to the state bucket and permission to manage ECR, ECS,
ELB, EC2 security groups, CloudWatch Logs and IAM roles.
