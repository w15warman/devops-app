terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.52.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }
  required_version = ">= 1.1.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = {
    name = "main"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id
  tags   = {
    Name = "internet_gateway"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table_association" "subnet_route" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_security_group" "security_group" {
  name   = "ecs-security-group"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = "false"
    cidr_blocks = ["0.0.0.0/0"]
    description = "any"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "ecs-template"
  image_id      = "ami-0e692fe1bae5ca24c"
  instance_type = "t2.micro"

  key_name               = "py-app-ssh"
  vpc_security_group_ids = [aws_security_group.security_group.id]
  iam_instance_profile {
    name = "ecsInstanceRole"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
      volume_type = "gp2"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = {
      Name = "ecs-instance"
    }
  }

  user_data = filebase64("${path.module}/ecs.sh")
}

resource "aws_autoscaling_group" "ecs_asg" {
  vpc_zone_identifier = [aws_subnet.subnet.id]
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1

  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}

#resource "aws_ecs_task_definition" "ecs_task_definition" {
#  family       = "my-ecs-task"
#  network_mode = "bridge"
#  cpu          = 1024
#  memory       = 256
#
#  container_definitions = jsonencode([
#    {
#      name               = "terr-py-app"
#      image              = "public.ecr.aws/a5u4v0o2/w15-container-repo:latest"
#      essential          = true
#      portMappings       = [
#        {
#          containerPort = 8080
#          hostPort      = 8080
#          protocol      = "tcp"
#        }
#      ]
#    }
#  ])
#}

#resource "aws_ecs_service" "ecs_service" {
#  name                               = "my-ecs-service"
#  cluster                            = aws_ecs_cluster.ecs_cluster.id
#  task_definition                    = aws_ecs_task_definition.ecs_task_definition.arn
#  scheduling_strategy                = "REPLICA"
#  desired_count                      = 1
#  launch_type                        = "EC2"
#  deployment_minimum_healthy_percent = 0
#
#  force_new_deployment = true
#  placement_constraints {
#    type = "distinctInstance"
#  }
#
#  triggers = {
#    redeployment = timestamp()
#  }
#
#  depends_on = [aws_autoscaling_group.ecs_asg]
#}