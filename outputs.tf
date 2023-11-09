output "context" {
  description = "The input context, a map, which is used for orchestration."
  value       = var.context
}

output "selector" {
  description = "The selector, a map, which is used for dependencies or collaborations."
  value       = local.labels
}

output "endpoint_internal" {
  description = "The internal endpoints, a string list, which are used for internal access."
  value       = [format("%s-master.%s.svc.%s:6379", local.name, local.namespace, local.domain_suffix)]
}

output "endpoint_internal_readonly" {
  description = "The internal readonly endpoints, a string list, which are used for internal readonly access."
  value       = var.deployment.type == "replication" ? [format("%s-replicas.%s.svc.%s:6379", local.name, local.namespace, local.domain_suffix)] : []
}

output "password" {
  value       = local.password
  description = "The password of redis service."
}
