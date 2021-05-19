job "${service_name}-worker" {
  type        = "service"
  datacenters = ["${datacenters}"]
  namespace   = "${namespace}"
  update {
    max_parallel      = 1
    health_check      = "checks"
    min_healthy_time  = "10s"
    healthy_deadline  = "55m"
    progress_deadline = "1h"
%{ if use_canary }
    canary            = 1
    auto_promote      = true
    auto_revert       = true
%{ endif }
    stagger           = "30s"
  }
  group "redash-worker" {
    count = 1

    network {
      mode = "bridge"
    }

    service {
      name = "${service_name}-worker"
      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "${redis_service}"
              local_bind_port  = "${redis_port}"
            }
            upstreams {
              destination_name = "${postgres_service}"
              local_bind_port  = "${postgres_port}"
            }
%{ for upstream in jsondecode(upstreams) }
            upstreams {
              destination_name = "${upstream.service_name}"
              local_bind_port  = "${upstream.port}"
            }
%{ endfor }
          }
        }
        sidecar_task {
          resources {
            cpu     = "${cpu_proxy}" # MHz
            memory  = "${memory_proxy}" #MB
          }
        }
      }
    }

    task "redash-worker" {
      driver  = "docker"
      config {
        image = "${image}"
        args  = ["worker"]
      }

      env {
        PYTHONUNBUFFERED = 0
        REDASH_LOG_LEVEL = "INFO"
        REDASH_REDIS_URL = "redis://$${NOMAD_UPSTREAM_ADDR_${redis_service}}/0"
        REDASH_DATABASE_URL        = "postgresql://postgres:postgres@$${NOMAD_UPSTREAM_ADDR_${postgres_service}}/postgres" // TODO! Fetch credentials from Vault
        REDASH_RATELIMIT_ENABLED = "false"
//        REDASH_MAIL_DEFAULT_SENDER = "redash@example.com"
//        REDASH_MAIL_SERVER = "email"
      }

      resources {
        cpu    = "${cpu}" # MHz
        memory = "${memory}" # MB
      }
    }
  }
}