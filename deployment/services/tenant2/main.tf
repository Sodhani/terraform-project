resource "aws_cloudwatch_log_group" "tenant2" {
  name              = "${var.name_prefix}-tenant2"
  retention_in_days = 1
}

resource "aws_ecs_task_definition" "tenant2" {
  family = "${var.name_prefix}-tenant2"

  container_definitions = <<EOF
[
  {
    "name": "tenant2",
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
        "awslogs-group": "${var.name_prefix}-tenant2",
        "awslogs-stream-prefix": "${var.name_prefix}-tenant2"
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

resource "aws_ecs_service" "tenant2" {
  name = "${var.name_prefix}-tenant2"
  cluster = var.cluster_id
  task_definition = aws_ecs_task_definition.tenant2.arn

  desired_count = 1
  force_new_deployment = true
  load_balancer {
    target_group_arn = var.alb_arn
    container_name = "tenant2"
    container_port = 3000
  }

  placement_constraints {
    type = "distinctInstance"
  }

  deployment_maximum_percent = 200
  deployment_minimum_healthy_percent = 100
}
