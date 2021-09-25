terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Create a VPC using a module
module "vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  name            = var.name
  cidr            = "10.0.0.0/16"
  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  public_subnets  = ["10.0.0.0/26", "10.0.0.64/26", "10.0.0.128/26"]
  private_subnets = ["10.0.16.0/26", "10.0.16.64/26", "10.0.16.128/26"]
}

# Create the ECS cluster
resource "aws_ecs_cluster" "default" {
  name = var.name
}

resource "aws_security_group" "lb" {
  name   = "${var.name}_lb"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group_rule" "lb_web_public" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lb.id
}

resource "aws_security_group_rule" "lb_egress" {
  type              = "egress"
  from_port         = -1
  to_port           = -1
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lb.id
}

resource "aws_lb" "default" {
  name            = var.name
  security_groups = [aws_security_group.lb.id]
  subnets         = module.vpc.public_subnets
}

resource "aws_lb_listener" "default" {
  load_balancer_arn = aws_lb.default.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

resource "aws_lb_target_group" "default" {
  name        = var.name
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  deregistration_delay = 0

  health_check {
    path    = "/ping"
    matcher = "200"
  }
}

resource "aws_ecr_repository" "default" {
  name = var.name
}

resource "aws_cloudwatch_log_group" "default" {
  name = "/ecs/${var.name}"
}

data "aws_caller_identity" "current" {}

resource "aws_ecs_task_definition" "default" {
  family             = var.name
  network_mode       = "awsvpc"
  execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"
  cpu                = "512"
  memory             = "1024"

  requires_compatibilities = ["FARGATE"]

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = "${aws_ecr_repository.default.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 4567
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group" : aws_cloudwatch_log_group.default.name,
          "awslogs-region" : var.region,
          "awslogs-stream-prefix" : "sinatra"
        }
      },
    },
  ])
}

resource "aws_security_group" "ecs" {
  name   = "${var.name}_ecs"
  vpc_id = module.vpc.vpc_id
}

resource "aws_security_group_rule" "lb_to_ecs" {
  type                     = "ingress"
  from_port                = 4567
  to_port                  = 4567
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb.id
  security_group_id        = aws_security_group.lb.id
}

resource "aws_security_group_rule" "ecs_egress" {
  type              = "egress"
  from_port         = -1
  to_port           = -1
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs.id
}

resource "aws_ecs_service" "default" {
  name = var.name

  cluster         = aws_ecs_cluster.default.id
  task_definition = aws_ecs_task_definition.default.arn
  desired_count   = 3
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.default.arn
    container_name   = var.name
    container_port   = 4567
  }

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.ecs.id]
  }
}

resource "aws_iam_user" "deploy" {
  name = "${var.name}-deploy"
}

resource "aws_iam_access_key" "deploy" {
  user = aws_iam_user.deploy.name
}

data "aws_iam_policy_document" "deploy" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]

    resources = [aws_ecr_repository.default.arn]
  }

  statement {
    actions   = ["ecs:UpdateService"]
    resources = [aws_ecs_service.default.id]
  }

  statement {
    actions   = ["ecs:DescribeServices"]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "deploy" {
  name   = "${var.name}-deploy"
  user   = aws_iam_user.deploy.name
  policy = data.aws_iam_policy_document.deploy.json
}

output "endpoint" { value = aws_lb.default.dns_name }
output "vpc_id" { value = module.vpc.vpc_id }
