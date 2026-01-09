output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.lb.dns_name
}
output "target_group_arn" {
  description = "The ARN of the Target Group"
  value       = aws_lb_target_group.alb-tg.arn
}