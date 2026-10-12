# Deploys the Go event service (app/platform-engineering-event-service) on ECS Fargate behind an ALB.
#
# Assumptions:
# - The account has a default VPC with at least two public subnets in different AZs.
# - Tasks run in those public subnets with public IPs (no NAT) so they can pull from ECR.
# - The ALB listens on HTTP :80 only; add an ACM certificate + HTTPS listener for production.
# - The image is built and pushed to the ECR repo separately (see output ecr_repository_url).

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_ecr_repository" "event_service" {
  name                 = var.event_service_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_cloudwatch_log_group" "event_service" {
  name              = "/ecs/${var.event_service_name}"
  retention_in_days = var.event_service_log_retention_days
}

resource "aws_security_group" "event_service_alb" {
  name_prefix = "${var.event_service_name}-alb-"
  description = "Public HTTP access to the ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "event_service_task" {
  name_prefix = "${var.event_service_name}-task-"
  description = "Allow traffic to the tasks from the ALB only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = var.event_service_port
    to_port         = var.event_service_port
    protocol        = "tcp"
    security_groups = [aws_security_group.event_service_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "event_service" {
  name               = var.event_service_name
  load_balancer_type = "application"
  security_groups    = [aws_security_group.event_service_alb.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "event_service" {
  name        = var.event_service_name
  port        = var.event_service_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "event_service_http" {
  load_balancer_arn = aws_lb.event_service.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.event_service.arn
  }
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: lets ECS pull the image from ECR and write logs.
resource "aws_iam_role" "event_service_execution" {
  name               = "${var.event_service_name}-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "event_service_execution" {
  role       = aws_iam_role.event_service_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_cluster" "event_service" {
  name = var.event_service_name
}

resource "aws_ecs_task_definition" "event_service" {
  family                   = var.event_service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.event_service_cpu
  memory                   = var.event_service_memory
  execution_role_arn       = aws_iam_role.event_service_execution.arn

  container_definitions = jsonencode([
    {
      name      = var.event_service_name
      image     = "${aws_ecr_repository.event_service.repository_url}:${var.event_service_image_tag}"
      essential = true

      portMappings = [{ containerPort = var.event_service_port, protocol = "tcp" }]

      environment = [
        { name = "PORT", value = tostring(var.event_service_port) },
        { name = "ENV", value = var.event_service_env },
        { name = "PROCESSING_DELAY_MS", value = tostring(var.event_service_processing_delay_ms) },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.event_service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "event_service" {
  name            = var.event_service_name
  cluster         = aws_ecs_cluster.event_service.id
  task_definition = aws_ecs_task_definition.event_service.arn
  desired_count   = var.event_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.event_service_task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.event_service.arn
    container_name   = var.event_service_name
    container_port   = var.event_service_port
  }

  depends_on = [aws_lb_listener.event_service_http]
}
