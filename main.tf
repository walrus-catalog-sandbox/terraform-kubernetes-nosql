locals {
  project_name     = coalesce(try(var.context["project"]["name"], null), "default")
  project_id       = coalesce(try(var.context["project"]["id"], null), "default_id")
  environment_name = coalesce(try(var.context["environment"]["name"], null), "test")
  environment_id   = coalesce(try(var.context["environment"]["id"], null), "test_id")
  resource_name    = coalesce(try(var.context["resource"]["name"], null), "example")
  resource_id      = coalesce(try(var.context["resource"]["id"], null), "example_id")

  namespace = coalesce(try(var.infrastructure.namespace, ""), join("-", [
    local.project_name, local.environment_name
  ]))
  image_registry = coalesce(var.infrastructure.image_registry, "registry-1.docker.io")
  domain_suffix  = coalesce(var.infrastructure.domain_suffix, "cluster.local")

  annotations = {
    "walrus.seal.io/project-id"     = local.project_id
    "walrus.seal.io/environment-id" = local.environment_id
    "walrus.seal.io/resource-id"    = local.resource_id
  }
  labels = {
    "walrus.seal.io/catalog-name"     = "terraform-kubernetes-redis"
    "walrus.seal.io/project-name"     = local.project_name
    "walrus.seal.io/environment-name" = local.environment_name
    "walrus.seal.io/resource-name"    = local.resource_name
  }

  architecture = coalesce(var.architecture, "standalone")
}

#
# Random
#

# create a random password for blank password input.

resource "random_password" "password" {
  length      = 16
  special     = false
  lower       = true
  min_lower   = 3
  min_upper   = 3
  min_numeric = 3
}

# create the name with a random suffix.

resource "random_string" "name_suffix" {
  length  = 10
  special = false
  upper   = false
}

locals {
  name     = join("-", [local.resource_name, random_string.name_suffix.result])
  password = coalesce(var.password, random_password.password.result)
}

#
# Deployment
#

locals {
  resources = {
    requests = try(var.resources != null, false) ? {
      cpu    = var.resources.cpu
      memory = "${var.resources.memory}Mi"
    } : null
    limits = try(var.resources != null, false) ? {
      memory = "${var.resources.memory}Mi"
    } : null
  }
  persistence = {
    enabled      = try(var.storage != null, false)
    storageClass = try(var.storage.class, "")
    accessModes  = ["ReadWriteOnce"]
    size         = try(format("%dMi", var.storage.size), "10240Mi")
  }
  service = {
    type = try(coalesce(var.infrastructure.service_type, "NodePort"), "NodePort")
  }

  values = [
    # basic configuration.

    {
      # global parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#global-parameters
      global = {
        image_registry = local.image_registry
      }

      # common parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#common-parameters
      fullnameOverride  = local.name
      commonAnnotations = local.annotations
      commonLabels      = local.labels
      clusterDomain     = local.domain_suffix

      # redis image parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#redis-image-parameters
      image = {
        repository = "bitnami/redis"
        tag        = coalesce(var.engine_version, "7.0")
      }

      # redis common parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#redis-common-configuration-parameters
      architecture = local.architecture
    },

    # standalone configuration.

    local.architecture == "standalone" ? {
      # redis master parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#redis-master-configuration-parameters
      master = {
        resources   = local.resources
        persistence = local.persistence
        service     = local.service
      }
    } : null,

    # replication configuration.

    local.architecture == "replication" ? {
      # redis master parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#redis-master-configuration-parameters
      master = {
        resources   = local.resources
        persistence = local.persistence
        service     = local.service
      }
      # redis replica parameters: https://github.com/bitnami/charts/tree/main/bitnami/redis#redis-replicas-configuration-parameters
      replica = {
        replicaCount = var.replication_readonly_replicas == 0 ? 1 : var.replication_readonly_replicas
        resources    = local.resources
        persistence  = local.persistence
        service      = local.service
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
    for c in local.values : yamlencode(c)
    if c != null
  ]

  set_sensitive {
    name  = "auth.password"
    value = local.password
  }
}
