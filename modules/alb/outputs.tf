output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.lb.dns_name
}
output "target_group_arn" {
  description = "The ARN of the Target Group"
  value       = aws_lb_target_group.alb-tg.arn
}
output "alb_security_group_id" {
  description = "The Security Group ID of the Application Load Balancer"
  value       = aws_security_group.lb_sg.id
}