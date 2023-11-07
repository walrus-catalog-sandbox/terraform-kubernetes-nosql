#
# Contextual Fields
#

variable "context" {
  description = <<-EOF
Receive contextual information. When Walrus deploys, Walrus will inject specific contextual information into this field.

Examples:
```
context:
  project:
    name: string
    id: string
  environment:
    name: string
    id: string
  resource:
    name: string
    id: string
```
EOF
  type        = map(any)
  default     = {}
}

#
# Infrastructure Fields
#

variable "infrastructure" {
  description = <<-EOF
Specify the infrastructure information for deploying.

Examples:
```
infrastructure:
  namespace: string, optional
  image_registry: string, optional
```
EOF
  type = object({
    namespace      = optional(string)
    image_registry = optional(string, "registry-1.docker.io")
  })
  default = {}
}

#
# Deployment Fields
#

variable "deployment" {
  description = <<-EOF
Specify the deployment action, including architecture and account.

Examples:
```
deployment:
  version: string, optional      # https://hub.docker.com/r/bitnami/redis/tags
  type: string, optional         # i.e. standalone, replication
  password: string
```
EOF
  type = object({
    version  = optional(string, "6.0.5")
    type     = optional(string, "standalone")
    password = string
  })
}

#
# Main Fields
#


variable "standalone" {
  description = <<-EOF
Specify the configuration of standalone deployment type.

Examples:
```
standalone:                      # one instance
  resources:
    requests:
      cpu: number
      memory: number             # in megabyte
    limits:
      cpu: number
      memory: number             # in megabyte
  storage:                       # convert to empty dir if null
    type: ephemeral/persistent
    ephemeral:                   # convert to volume claim template
      class: string
      access_mode: string
      size: number, optional     # in megabyte
    persistent:                  # convert to persistent volume claim
      name: string
```
EOF
  type = object({
    resources = optional(object({
      requests = object({
        cpu    = optional(number, 0.25)
        memory = optional(number, 256)
      })
      limits = optional(object({
        cpu    = optional(number, 0)
        memory = optional(number, 0)
      }))
    }), { requests = { cpu = 0.25, memory = 256 } })
    storage = optional(object({
      type = optional(string, "ephemeral")
      ephemeral = optional(object({
        class       = optional(string)
        access_mode = optional(string, "ReadWriteOnce")
        size        = optional(number)
      }))
      persistent = optional(object({
        name = string
      }))
    }))
  })
  default = {}
}

variable "replication" {
  description = <<-EOF
Specify the configuration of replication deployment type.

Examples:
```
replication:                     # four instances: one master, three read-only replicas
  master:
    resources:
      requests:
        cpu: number
        memory: number           # in megabyte
      limits:
        cpu: number
        memory: number           # in megabyte
    storage:                     # convert to empty dir if null
      type: ephemeral/persistent
      ephemeral:                 # convert to dynamic claim template
        class: string
        access_mode: string
        size: number, optional   # in megabyte
      persistent:                # convert to existing volume claim
        name: string             # the name of persistent volume claim
  replicas:
    resources:
      requests:
        cpu: number
        memory: number           # in megabyte
      limits:
        cpu: number
        memory: number           # in megabyte
    storage:                     # convert to empty dir if null
      type: ephemeral/persistent
      ephemeral:                 # convert to volume claim template
        class: string
        access_mode: string
        size: number, optional   # in megabyte
      persistent:                # convert to persistent volume claim
        name: string
```
EOF
  type = object({
    master = optional(object({
      resources = optional(object({
        requests = object({
          cpu    = optional(number, 0.25)
          memory = optional(number, 256)
        })
        limits = optional(object({
          cpu    = optional(number, 0)
          memory = optional(number, 0)
        }))
      }), { requests = { cpu = 0.25, memory = 256 } })
      storage = optional(object({
        type = optional(string, "ephemeral")
        ephemeral = optional(object({
          class       = optional(string)
          access_mode = optional(string, "ReadWriteOnce")
          size        = optional(number)
        }))
        persistent = optional(object({
          name = string
        }))
      }))
    }), { requests = { cpu = 0.25, memory = 256 } })
    replicas = optional(object({
      resources = optional(object({
        requests = object({
          cpu    = optional(number, 0.25)
          memory = optional(number, 256)
        })
        limits = optional(object({
          cpu    = optional(number, 0)
          memory = optional(number, 0)
        }))
      }), { requests = { cpu = 0.25, memory = 256 } })
      storage = optional(object({
        type = optional(string, "ephemeral")
        ephemeral = optional(object({
          class       = optional(string)
          access_mode = optional(string, "ReadWriteOnce")
          size        = optional(number)
        }))
        persistent = optional(object({
          name = string
        }))
      }))
    }), { requests = { cpu = 0.25, memory = 256 } })
  })
  default = {}
}