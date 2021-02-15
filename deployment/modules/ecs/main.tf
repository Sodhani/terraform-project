resource "aws_ecs_cluster" "this" {
  count = var.create_ecs ? 1 : 0

  name = "${var.name}-multi"
  tags = var.tags
}

resource "aws_ecs_cluster" "this_tenant2" {
  count = var.create_ecs ? 1 : 0

  name = "${var.name}-single"
  tags = var.tags
}

