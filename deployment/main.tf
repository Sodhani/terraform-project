terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "2.70.0"
    }
  }
}

# AWS Region
provider "aws" {
  region = "us-east-2"
}

#Local variables to be used
locals {
  name        = "raj"
  environment = "demo"
  region = "us-east-2"
  root_domain = "sodhani.xyz"
  name_prefix = "${local.name}-${local.environment}"
}

# This s3 bucket will store the terraform state, to be changed when run by another user
terraform {
  backend "s3" {
    bucket = "sodhani-test-bucket"
    key    = "terraform.tfstate"
    region = "us-east-2"
  }
}

#Fetch the hosted zone name
data "aws_route53_zone" "zone" {
  name         = local.root_domain
  private_zone = false
}

#Code to setup cloudfront
module "aws_static_website" {
  source = "cloudmaniac/static-website/aws"

  website-domain-main     = local.root_domain
  website-domain-redirect = "www.${local.root_domain}"
}

# VPC created for multi-tenants
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.60.0"

  name = "${local.name_prefix}-vpc"

  cidr = "10.1.0.0/16"

  azs              = ["${local.region}a", "${local.region}b"]
  private_subnets  = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets   = ["10.1.11.0/24", "10.1.12.0/24"]
  database_subnets = ["10.1.111.0/24", "10.1.121.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "${local.environment}-vpc"
    Name        = "${local.name}-vpc"
  }
}

#VPC created for single tenant (here it ill be tenant2)
module "vpc_tenant2" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.60.0"

  name = "${local.name_prefix}-vpc_tenant2"

  cidr = "10.1.0.0/16"

  azs             = ["${local.region}a", "${local.region}b"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.11.0/24", "10.1.12.0/24"]
  database_subnets = ["10.1.111.0/24", "10.1.121.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "${local.environment}-vpc_tenant2"
    Name        = "${local.name}-vpc_tenant2"
  }
}

#Application load balancer security group created for multi-tenants
resource "aws_security_group" "alb_sec_group" {
  name        = "${local.name_prefix}-alb-sec-group"
  description = "${local.name_prefix}-alb-sec-group"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "${local.environment}-alb_sec_group"
    Name        = "${local.name}-alb_sec_group"
  }
}

#Application load balancer security group created for single tenant (tenant2)
resource "aws_security_group" "alb_sec_group_tenant2" {
  name        = "${local.name_prefix}-alb-sec-group-tenant2"
  description = "${local.name_prefix}-alb-sec-group-tenant2"
  vpc_id      = module.vpc_tenant2.vpc_id
	
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "${local.environment}-alb_sec_group_tenant2"
    Name        = "${local.name}-alb_sec_group_tenant2"
  }
}

#EC2 security group created for each tenant
resource "aws_security_group" "ec2_sec_group_tenant3" {
  name        = "${local.name_prefix}-ec2-sec-group-tenant3"
  description = "${local.name_prefix}-ec2-sec-group-tenant3"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb_sec_group.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "${local.environment}-ec2_sec_group_tenant3"
    Name        = "${local.name}-ec2_sec_group_tenant3"
  }
}

#EC2 security group created for each tenant
resource "aws_security_group" "ec2_sec_group_tenant1" {
  name        = "${local.name_prefix}-ec2-sec-group-tenant1"
  description = "${local.name_prefix}-ec2-sec-group-tenant1"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb_sec_group.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "${local.environment}-ec2_sec_group_tenant1"
    Name        = "${local.name}-ec2_sec_group_tenant1"
  }
}


#EC2 security group created for each tenant
resource "aws_security_group" "ec2_sec_group_tenant2" {
  name        = "${local.name_prefix}-ec2_sec-group-tenant2"
  description = "${local.name_prefix}-ec2_sec-group-tenant2"
  vpc_id      = module.vpc_tenant2.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb_sec_group_tenant2.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "${local.environment}-ec2_sec_group_tenant2"
    Name        = "${local.name}-ec2_sec_group_tenant2"
  }
}

#Application Load Balancer Listener for multi-tenants
resource "aws_lb" "alb" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sec_group.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = {
    Environment = "${local.environment}-alb"
    Name        = "${local.name}-alb"
  }
}

#Application load balancer Listener for single-tenant
resource "aws_lb" "alb_tenant2" {
  name               = "${local.name_prefix}-alb-tenant2"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sec_group_tenant2.id]
  subnets            = module.vpc_tenant2.public_subnets

  enable_deletion_protection = false

  tags = {
    Environment = "${local.environment}-alb_tenant2"
    Name        = "${local.name}-alb_tenant2"
  }
}

#Taget group for each tenant
resource "aws_lb_target_group" "alb_target_tenant3" {
  name     = "${local.name_prefix}-alb-target-tenant3"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  depends_on = [
    aws_lb.alb
  ]

  health_check {
    enabled = true
    path = "/"
    interval = 6
    timeout = 5
  }

  tags = {
    Environment = "${local.environment}-alb_target_tenant3"
    Name        = "${local.name}-alb_target_tenant3"
  }
}

#Taget group for each tenant
resource "aws_lb_target_group" "alb_target_tenant1" {
  name     = "${local.name_prefix}-alb-target-tenant1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  depends_on = [
    aws_lb.alb
  ]

  health_check {
    enabled = true
    path = "/"
    interval = 6
    timeout = 5
  }

  tags = {
    Environment = "${local.environment}-alb_target_tenant1"
    Name        = "${local.name}-alb_target_tenant1"
  }
}

#Taget group for each tenant
resource "aws_lb_target_group" "alb_target_tenant2" {
  name     = "${local.name_prefix}-alb-target-tenant2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc_tenant2.vpc_id

  depends_on = [
    aws_lb.alb_tenant2
  ]

  health_check {
    enabled = true
    path = "/"
    interval = 6
    timeout = 5
  }

  tags = {
    Environment = "${local.environment}-alb_target_tenant2"
    Name        = "${local.name}-alb_target_tenant2"
  }
}

#Listener to redirect HTTP requests for multi-tenants
resource "aws_lb_listener" "alb_listener_http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

#Listener to redirect HTTP requests for single-tenant
resource "aws_lb_listener" "alb_listener_http_tenant2" {
  load_balancer_arn = aws_lb.alb_tenant2.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

#Fetch the certificate details issued for the domain
data "aws_acm_certificate" "cert" {
  domain = "www.${local.root_domain}"
  statuses = ["ISSUED"]
  most_recent =  true
}

#Used it earlier to create the certificate, kept it as is for reference
#resource "aws_acm_certificate" "cert" {
#  domain_name       = local.root_domain
#  subject_alternative_names = ["*.${local.root_domain}"]
#  validation_method = "DNS"
#
#  tags = {
#    Environment = local.environment
#    Name        = local.name
#  }
#
#  lifecycle {
#    create_before_destroy = true
#  }
#}

#Listener for HTTPS requests, for multi-tenants
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  #certificate_arn  = aws_acm_certificate_validation.cert.certificate_arn  Used when creating certificate on the go
  certificate_arn = data.aws_acm_certificate.cert.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content for unregistered tenants"
      status_code  = "200"
    }
  }
}

#Listener for HTTPS requests, for single-tenant
resource "aws_lb_listener" "alb_listener_tenant2" {
  load_balancer_arn = aws_lb.alb_tenant2.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  #certificate_arn  = aws_acm_certificate_validation.cert.certificate_arn  Used when creating certificate on the go
  certificate_arn = data.aws_acm_certificate.cert.arn

  default_action {
    type = "fixed-response"
  
    fixed_response {
      content_type = "text/plain"
      message_body = "Fixed response content for unregistered tenants"
      status_code  = "200"
    }
  }
}

#Listener rule for each tenant
resource "aws_lb_listener_rule" "alb_listener_rule_tenant1" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_tenant1.arn
  }

  condition {
    host_header {
      values = ["tenant1.${local.root_domain}"]
    }
  }
}

#Listener rule for each tenant
resource "aws_lb_listener_rule" "alb_listener_rule_tenant2" {
  listener_arn = aws_lb_listener.alb_listener_tenant2.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_tenant2.arn
  }

  condition {
    host_header {
      values = ["tenant2.${local.root_domain}"]
    }
  }
}

#Listener rule for each tenant
resource "aws_lb_listener_rule" "alb_listener_rule_tenant3" {
  listener_arn = aws_lb_listener.alb_listener.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_tenant3.arn
  }

  condition {
    host_header {
      values = ["tenant3.${local.root_domain}"]
    }
  }
}

#Pass and run the ecs module to setup the EC2 instances in ECS
module "ecs" {
  source = "./modules/ecs"
  name   = local.name_prefix
  tags = {
    Environment = "${local.environment}-ecs"
    Name        = "${local.name}-ecs"
  }
}

#Module to setup the ECS using IAM roles
module "ec2-profile" {
  source = "./modules/ecs-instance-profile"
  name   = "${local.name_prefix}-ec2-profile"
}

#Setup the service to be run for each tenant.
module "tenant3-service" {
  source     = "./services/tenant3"
  cluster_id = module.ecs.this_ecs_cluster_id
  alb_arn = aws_lb_target_group.alb_target_tenant3.arn
  name = "${local.name}-tenant3"
  name_prefix = local.name_prefix
  environment = local.environment
  region = local.region
  image_url = var.main_service_image_url
}

#Setup the service to be run for each tenant.
module "tenant1-service" {
  source     = "./services/tenant1"
  cluster_id = module.ecs.this_ecs_cluster_id
  alb_arn = aws_lb_target_group.alb_target_tenant1.arn
  name = "${local.name}-tenant1"
  name_prefix = local.name_prefix
  environment = local.environment
  region = local.region
  image_url = var.main_service_image_url
}

#Setup the service to be run for each tenant.
module "tenant2-service" {
  source     = "./services/tenant2"
  cluster_id = module.ecs.this_tenant2_ecs_cluster_id
  alb_arn = aws_lb_target_group.alb_target_tenant2.arn
  name = "${local.name}-tenant2"
  name_prefix = local.name_prefix
  environment = local.environment
  region = local.region
  image_url = var.main_service_image_url
}

#Search for the required AMI
data "aws_ami" "amazon_linux_ecs" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  tags = {
    Environment = "${local.environment}-amazon_linux_ecs"
    Name        = "${local.name}-amazon_linux_ecs"
  }
}

#Setup autoscaling group for each tenant.
module "this_tenant3" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "3.8.0"

  name = "${local.name_prefix}-as-tenant3"

  lc_name = "${local.name_prefix}-aslc-tenant3"

  image_id             = data.aws_ami.amazon_linux_ecs.id
  instance_type        = "t2.micro"

  security_groups      = [aws_security_group.ec2_sec_group_tenant3.id]
  iam_instance_profile = module.ec2-profile.this_iam_instance_profile_id
  user_data            = data.template_file.user_data.rendered

  asg_name                  = "${local.name_prefix}-asg_tenant3"
  vpc_zone_identifier       = module.vpc.private_subnets
  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  placement_tenancy         = "default"

  tags = [
    {
      key                 = "Environment"
      value               = "${local.environment}-environment"
      propagate_at_launch = true
    },
    {
      key                 = "Cluster"
      value               = "${local.name}-cluster"
      propagate_at_launch = true
    },
  ]
}

#Setup autoscaling group for each tenant.
module "this_tenant1" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "3.8.0"

  name = "${local.name_prefix}-as-tenant1"

  lc_name = "${local.name_prefix}-aslc-tenant1"

  image_id             = data.aws_ami.amazon_linux_ecs.id
  instance_type        = "t2.micro"

  security_groups      = [aws_security_group.ec2_sec_group_tenant1.id]
  iam_instance_profile = module.ec2-profile.this_iam_instance_profile_id
  user_data            = data.template_file.user_data.rendered

  asg_name                  = "${local.name_prefix}-asg_tenant1"
  vpc_zone_identifier       = module.vpc.private_subnets
  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  placement_tenancy         = "default"

  tags = [
    {
      key                 = "Environment"
      value               = "${local.environment}-environment"
      propagate_at_launch = true
    },
    {
      key                 = "Cluster"
      value               = "${local.name}-cluster"
      propagate_at_launch = true
    },
  ]
}

#Setup autoscaling group for each tenant.
module "this_tenant2" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "3.8.0"

  name = "${local.name_prefix}-as-tenant2"

  lc_name = "${local.name_prefix}-aslc-tenant2"

  image_id             = data.aws_ami.amazon_linux_ecs.id
  instance_type        = "t2.micro"

  security_groups      = [aws_security_group.ec2_sec_group_tenant2.id]
  iam_instance_profile = module.ec2-profile.this_iam_instance_profile_id
  user_data            = data.template_file.user_data_tenant2.rendered

  asg_name                  = "${local.name_prefix}-asg_tenant2"
  vpc_zone_identifier       = module.vpc_tenant2.private_subnets
  health_check_type         = "EC2"
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  placement_tenancy         = "default"

  tags = [
    {
      key                 = "Environment"
      value               = "${local.environment}-environment_tenant2"
      propagate_at_launch = true
    },
    {
      key                 = "Cluster"
      value               = "${local.name}-cluster_tenant2"
      propagate_at_launch = true
    },
  ]
}

#Specify the cluster where the tasks are to be run
data "template_file" "user_data" {
  template = file("${path.module}/templates/user-data.sh")

  vars = {
    cluster_name = "${local.name_prefix}-multi"
  }
}

data "template_file" "user_data_tenant2" {
  template = file("${path.module}/templates/user-data.sh")

  vars = {
    cluster_name = "${local.name_prefix}-single"
  }
}

#Used for certificate validation, as certificates are created already, we will not need these
#resource "aws_route53_record" "cert_validation" {
#  name    = tolist(data.aws_acm_certificate.cert.domain_validation_options)[0].resource_record_name
#  type    = tolist(data.aws_acm_certificate.cert.domain_validation_options)[0].resource_record_type
#  zone_id = "${data.aws_route53_zone.zone.id}"
#  records = [tolist(data.aws_acm_certificate.cert.domain_validation_options)[0].resource_record_value]
#  ttl     = 60
#}

#resource "aws_acm_certificate_validation" "cert" {
#  certificate_arn         = "${aws_acm_certificate.cert.arn}"
#  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
#}

#Create route53 records for each subdomain(tenant) and for the domain
resource "aws_route53_record" "generic" {
  zone_id = data.aws_route53_zone.zone.id
  name    = "*.${local.root_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "tenant3" {
  zone_id = data.aws_route53_zone.zone.id
  name    = "tenant3.${local.root_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "tenant1" {
  zone_id = data.aws_route53_zone.zone.id
  name    = "tenant1.${local.root_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "tenant2" {
  zone_id = data.aws_route53_zone.zone.id
  name    = "tenant2.${local.root_domain}"
  type    = "A"

  alias {
    name                   = aws_lb.alb_tenant2.dns_name
    zone_id                = aws_lb.alb_tenant2.zone_id
    evaluate_target_health = true
  }
}

#Create subnet group for the DB for multi-tenants
resource "aws_db_subnet_group" "db-subnet-group" {
  name  = "${local.name}-db"
  subnet_ids = module.vpc.database_subnets
}

#Create subnet group for the DB for single-tenant
resource "aws_db_subnet_group" "db-subnet-group_tenant2" {
  name  = "${local.name}-db-tenant2"
  subnet_ids = module.vpc_tenant2.database_subnets
}

#Create the DB instance for multi-tenants
resource "aws_db_instance" "mysql" {
  identifier_prefix = "${local.name}-db"
  engine = "mysql"
  allocated_storage = 10
  max_allocated_storage = 20
  db_subnet_group_name = aws_db_subnet_group.db-subnet-group.id
  vpc_security_group_ids = [aws_security_group.mysql-sec-group.id]
  instance_class = "db.t2.micro"
  skip_final_snapshot = true
  backup_retention_period = 0
  apply_immediately = true
  name = "${local.name}mysqldb"
  username  = "admin"
  password = "12345678"
}

#Create the DB instance for single-tenant
resource "aws_db_instance" "mysql_tenant2" {
  identifier_prefix = "${local.name}-db-tenant2"
  engine = "mysql"
  allocated_storage = 10
  max_allocated_storage = 20
  db_subnet_group_name = aws_db_subnet_group.db-subnet-group_tenant2.id
  vpc_security_group_ids = [aws_security_group.mysql-sec-group_tenant2.id]
  instance_class = "db.t2.micro"
  skip_final_snapshot = true
  backup_retention_period = 0
  apply_immediately = true
  name = "${local.name}mysqldbtenant2"
  username  = "admin"
  password = "12345678"
}

#Setup the DB security group for multi-tenants
resource "aws_security_group" "mysql-sec-group" {
  name = "${local.name}-rds-sg"

  description = "RDS"
  vpc_id      = module.vpc.vpc_id

  # Only MySQL in
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Setup the DB security group for single-tenant
resource "aws_security_group" "mysql-sec-group_tenant2" {
  name = "${local.name}-rds-sg-tenant2"

  description = "RDS"
  vpc_id      = module.vpc_tenant2.vpc_id

  # Only MySQL in
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

