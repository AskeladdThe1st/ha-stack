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
  source  = "./modules/vpc"
}

module "alb" {
  source  = "./modules/alb"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

// App tier
resource "aws_launch_template" "launch_template" {
  name_prefix   = "ha-app-server-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  availability_zones = ["us-west-2a", "us-west-2b"]
  desired_capacity   = 2
  max_size           = 3
  min_size           = 1

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }
}
