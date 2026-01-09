provider "aws" {
  region = "us-west-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

// Web tier
module "vpc" {
  source = "./modules/vpc"
}

module "alb" {
  source                = "./modules/alb"
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = aws_security_group.alb-sg.id
}

resource "aws_security_group" "alb-sg" {
  name        = "alb-sg"
  description = "Allow inbound traffic to load balancer"
  vpc_id      = module.vpc.vpc_id

}
resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb-sg.id
}
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb-sg.id
}

// App tier
resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "Allow inbound traffic ONLY from ALB"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "app-sg"
  }
}
resource "aws_security_group_rule" "allow_inbound_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.alb-sg.id
}
resource "aws_security_group_rule" "allow_outbound_alb" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app_sg.id
}

resource "aws_launch_template" "launch_template" {
  name_prefix            = "ha-app-server-"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_profile.name
  }
  lifecycle {
    create_before_destroy = true
  }
  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt-get update
              apt-get upgrade -y
              apt-get install -y nginx
              systemctl start nginx
              systemctl enable nginx
              EOF
  )
}

resource "aws_autoscaling_group" "asg" {
  name                = "ha-app-asg-${aws_launch_template.launch_template.latest_version}"

  vpc_zone_identifier = module.vpc.private_subnet_ids
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  target_group_arns   = [module.alb.target_group_arn]
  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50 
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "cpu_scaling" {
  name                   = "cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 20.0 # Maintain 50% average CPU across the fleet
  }
}