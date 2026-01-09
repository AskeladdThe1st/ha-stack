resource "aws_lb" "lb" {
  name               = var.lb_name
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  enable_deletion_protection = false
  security_groups = [var.alb_security_group_id]

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "alb-listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-tg.arn
  }
}
resource "aws_lb_target_group" "alb-tg" {
  name        = var.tg-name
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  health_check {
    enabled             = true
    interval            = 30
    path                = "/"
    port                = "traffic-port" # This uses port 80 defined above
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200" # Expects a success code from Nginx
  }
}

