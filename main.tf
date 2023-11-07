locals {
  project_name     = coalesce(try(var.context["project"]["name"], null), "default")
  project_id       = coalesce(try(var.context["project"]["id"], null), "default_id")
  environment_name = coalesce(try(var.context["environment"]["name"], null), "test")
  environment_id   = coalesce(try(var.context["environment"]["id"], null), "test_id")
  resource_name    = coalesce(try(var.context["resource"]["name"], null), "example")
  resource_id      = coalesce(try(var.context["resource"]["id"], null), "example_id")

  architecture = coalesce(try(var.deployment.type), "replication")
  namespace = coalesce(try(var.infrastructure.namespace, ""), join("-", [
    local.project_name, local.environment_name
  ]))
  annotations = {
    "walrus.seal.io/project-id"     = local.project_id
    "walrus.seal.io/environment-id" = local.environment_id
    "walrus.seal.io/resource-id"    = local.resource_id
  }
  labels = {
    "walrus.seal.io/project-name"     = local.project_name
    "walrus.seal.io/environment-name" = local.environment_name
    "walrus.seal.io/resource-name"    = local.resource_name
  }
}

#
# Random
#

# create the name with a random suffix.

resource "random_string" "name_suffix" {
  length  = 10
  special = false
  upper   = false
}

locals {
  name = join("-", [local.resource_name, random_string.name_suffix.result])
}

#
# Deployment
#

locals {
  helm_release_values = [
    # basic configuration.

    {
      # global parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#global-parameters
      global = {
        image_registry = coalesce(var.infrastructure.image_registry, "registry-1.docker.io")
      }

      # common parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#common-parameters
      fullnameOverride  = local.name
      commonAnnotations = local.annotations
      commonLabels      = local.labels

      # redis image parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#redis-image-parameters
      image = {
        repository = "bitnami/redis"
        tag        = coalesce(var.deployment.version, "7.2.3")
      }

      # redis common parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#redis-common-configuration-parameters
      architecture = local.architecture
    },

    # standalone configuration.

    local.architecture == "standalone" ? {
      # redis master parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#redis-master-configuration-parameters
      master = {
        resources = {
          requests = try(var.standalone.resources.requests != null, false) ? {
            for k, v in var.standalone.resources.requests : k => "%{if k == "memory"}${v}Mi%{else}${v}%{endif}"
            if v != null && v > 0
          } : null
          limits = try(var.standalone.resources.limits != null, false) ? {
            for k, v in var.standalone.resources.limits : k => "%{if k == "memory"}${v}Mi%{else}${v}%{endif}"
            if v != null && v > 0
          } : null
        }
        persistence = {
          enabled       = try(var.standalone.storage != null, false)
          storageClass  = try(var.standalone.storage.ephemeral.class, "")
          accessModes   = [try(var.standalone.storage.ephemeral.access_mode, "ReadWriteOnce")]
          size          = try(format("%dMi", var.standalone.storage.ephemeral.size), "8Gi")
          existingClaim = try(var.standalone.storage.persistent.name, "")
        }
      }
    } : null,

    # replication configuration.

    local.architecture == "replication" ? {
      # redis master parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#redis-master-configuration-parameters
      master = {
        resources = {
          requests = try(var.replication.master.resources.requests != null, false) ? {
            for k, v in var.replication.master.resources.requests : k => "%{if k == "memory"}${v}Mi%{else}${v}%{endif}"
            if v != null && v > 0
          } : null
          limits = try(var.replication.master.resources.limits != null, false) ? {
            for k, v in var.replication.master.resources.limits : k => "%{if k == "memory"}${v}Mi%{else}${v}%{endif}"
            if v != null && v > 0
          } : null
        }
        persistence = {
          enabled       = try(var.replication.master.storage != null, false)
          storageClass  = try(var.replication.master.storage.ephemeral.class, "")
          accessModes   = [try(var.replication.master.storage.ephemeral.access_mode, "ReadWriteOnce")]
          size          = try(format("%dMi", var.replication.master.storage.ephemeral.size), "8Gi")
          existingClaim = try(var.replication.master.storage.persistent.name, "")
        }
      }
      # redis replica parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#redis-replicas-configuration-parameters
      replicas = {
        resources = {
          requests = try(var.replication.replicas.resources.requests != null, false) ? {
            for k, v in var.replication.replicas.resources.requests : k => "%{if k == "memory"}${v}Mi%{else}${v}%{endif}"
            if v != null && v > 0
          } : null
          limits = try(var.replication.replicas.resources.limits != null, false) ? {
            for k, v in var.replication.replicas.resources.limits : k => "%{if k == "memory"}${v}Mi%{else}${v}%{endif}"
            if v != null && v > 0
          } : null
        }
        persistence = {
          enabled       = try(var.replication.replicas.storage != null, false)
          storageClass  = try(var.replication.replicas.storage.ephemeral.class, "")
          accessModes   = [try(var.replication.replicas.storage.ephemeral.access_mode, "ReadWriteOnce")]
          size          = try(format("%dMi", var.replication.replicas.storage.ephemeral.size), "8Gi")
          existingClaim = try(var.replication.replicas.storage.persistent.name, "")
        }
      }
    } : null,
  ]
}

resource "helm_release" "redis" {
  chart       = "${path.module}/charts/redis-18.2.1.tgz"
  wait        = false
  max_history = 3
  namespace   = local.namespace
  name        = local.name

  values = [
    for c in local.helm_release_values : yamlencode(c)
    if c != null
  ]

  set_sensitive {
    name  = "auth.password"
    value = var.deployment.password
  }
}