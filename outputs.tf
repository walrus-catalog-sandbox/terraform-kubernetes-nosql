#
# Contextual output
#

output "context" {
  description = "The input context, a map, which is used for orchestration."
  value       = var.context
}

#
# Module output
#

output "endpoint_internal" {
  description = "The internal endpoints, a string list, which are used for internal access."
  value       = [format("%s-master.%s.svc", local.name, local.namespace)]
}

output "endpoint_internal_readonly" {
  description = "The internal readonly endpoints, a string list, which are used for internal readonly access."
  value       = var.deployment.type == "replication" ? [format("%s-replicas.%s.svc", local.name, local.namespace)] : null
}

output "port" {
  value       = "6379"
  description = "The port of redis service."
}

output "password" {
  value       = var.deployment.password
  description = "The password of redis service."
}