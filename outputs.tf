output "vpc_id" {
  value = module.network.vpc_id
}

output "alb_dns_name" {
  description = "Load this URL in a browser to hit the app tier through the ALB"
  value       = module.compute.alb_dns_name
}

output "rds_endpoint" {
  value     = module.database.db_endpoint
  sensitive = true
}
