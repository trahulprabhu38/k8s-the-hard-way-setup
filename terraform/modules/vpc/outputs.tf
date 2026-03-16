output "vpc_id" {
  description = "VPC ID"
  value       = var.testing ? null : aws_vpc.vpc[0].id
}

output "public_subnet_ids" {
  description = "Map of public subnet IDs keyed by subnet name"
  value       = var.testing ? {} : { for k, v in aws_subnet.public : k => v.id }
}

output "private_subnet_ids" {
  description = "Map of private subnet IDs keyed by subnet name"
  value       = var.testing ? {} : { for k, v in aws_subnet.private : k => v.id }
}
