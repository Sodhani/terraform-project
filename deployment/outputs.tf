#output "docker_registry" {
#  description = "docker_registry"
#  value       = aws_ecr_repository.repository.repository_url
#}

output "root_domain" {
  description = "root_domain"
  value       = local.root_domain
}

