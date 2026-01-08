variable "lb_name" {
  description = "The name of the load balancer."
  type        = string
  default     = "my-alb"
}
variable "tg-name" {
  description = "The name of the target group."
  type        = string
  default     = "my-alb-tg"
}
variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB."
  type        = list(string)
}
variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}
variable "alb_security_group_id" {
  description = "The Security Group ID for the ALB."
  type        = string
}