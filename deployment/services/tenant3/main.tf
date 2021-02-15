resource "aws_cloudwatch_log_group" "tenant3" {
  name              = "${var.name_prefix}-tenant3"
  retention_in_days = 1
}

resource "aws_ecs_task_definition" "tenant3" {
  family = "${var.name_prefix}-tenant3"

  container_definitions = <<EOF
[
  {
    "name": "tenant3",
    "image": "${var.image_url}",
    "cpu": 400,
    "memory": 320,
    "portMappings": [
      {
        "containerPort": 3000,
        "hostPort": 0
      }
    ],
    "environment": [
    {
      "name": "NODE_ENV",
      "value": "${var.environment}"
    },
    {
      "name": "PORT",
      "value": "3000"
    }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "${var.region}",
        "awslogs-group": "${var.name_prefix}-tenant3",
        "awslogs-stream-prefix": "${var.name_prefix}-tenant3"
      }
    }
  }
]
EOF

  tags = {
    Environment = var.environment
    Name        = var.name
  }
}

resource "aws_ecs_service" "tenant3" {
  name = "${var.name_prefix}-tenant3"
  cluster = var.cluster_id
  task_definition = aws_ecs_task_definition.tenant3.arn

  desired_count = 1
  force_new_deployment = true
  load_balancer {
    target_group_arn = var.alb_arn
    container_name = "tenant3"
    container_port = 3000
  }

  placement_constraints {
    type = "distinctInstance"
  }

  deployment_maximum_percent = 200
  deployment_minimum_healthy_percent = 100
}
