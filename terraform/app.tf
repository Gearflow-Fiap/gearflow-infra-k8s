# ── Secret (dados sensíveis) ──────────────────────────────────────────────
# API deployment e HPA vivem no gearflow-app (Repo 4)
resource "kubernetes_secret" "gearflow" {
  metadata {
    name      = "gearflow-secret"
    namespace = kubernetes_namespace.gearflow.metadata[0].name
  }

  data = {
    # var.db_endpoint às vezes vem com a porta já embutida (ex.: output do
    # gearflow-infra-database inclui ":1433") — normaliza pra não duplicar a porta.
    "ConnectionStrings__GearFlow" = "Server=${split(":", var.db_endpoint)[0]},${var.db_port};Database=${var.db_name};User Id=${var.db_user};Password=${var.db_password};Encrypt=True;TrustServerCertificate=True"
    "Jwt__Secret"                 = var.jwt_signing_key
    # Agente APM .NET (lido pelo Dockerfile/newrelic.config) + header OTLP para métricas de negócio
    NEW_RELIC_LICENSE_KEY       = var.newrelic_license_key
    OTEL_EXPORTER_OTLP_HEADERS  = "api-key=${var.newrelic_license_key}"
  }
}

# ── ConfigMap (dados não sensíveis) ──────────────────────────────────────
resource "kubernetes_config_map" "gearflow" {
  metadata {
    name      = "gearflow-configmap"
    namespace = kubernetes_namespace.gearflow.metadata[0].name
  }

  data = {
    ASPNETCORE_ENVIRONMENT    = "Production"
    ASPNETCORE_HTTP_PORTS     = "8080"
    # Habilita a massa de dados fictícios (demo) mesmo em Production.
    "Seed__EnableDevData"     = "true"
    "Jwt__Issuer"             = "GearFlow.Api"
    "Jwt__Audience"           = "GearFlow.Client"
    "Jwt__AccessTokenMinutes" = "30"
    "Jwt__RefreshTokenDays"   = "7"
    "Jwt__LockoutMinutes"     = "15"
    "Email__Host"             = "smtp-service"
    "Email__Port"             = "1025"
    "Email__From"             = "sistema@gearflow.com"
    "App__PublicBaseUrl"      = "https://${var.cluster_name}.api.gearflow.com"
    # Métricas de negócio (serviceorders.created, serviceorder.status.duration, integration.errors)
    # exportadas via OTLP para o New Relic — alimentam o dashboard custom (newrelic-dashboard.tf).
    "Otlp__Endpoint"          = "https://otlp.nr-data.net:4317"
    # New Relic APM
    CORECLR_ENABLE_PROFILING                              = "1"
    CORECLR_PROFILER                                      = "{36032161-FFC0-4B61-B559-F6C5D41BAE5A}"
    CORECLR_NEWRELIC_HOME                                 = "/app/newrelic"
    CORECLR_PROFILER_PATH                                 = "/app/newrelic/libNewRelicProfiler.so"
    NEW_RELIC_APP_NAME                                    = "GearFlow.Api"
    NEW_RELIC_DISTRIBUTED_TRACING_ENABLED                 = "true"
    NEW_RELIC_APPLICATION_LOGGING_ENABLED                 = "true"
    NEW_RELIC_APPLICATION_LOGGING_FORWARDING_ENABLED      = "true"
    NEW_RELIC_APPLICATION_LOGGING_LOCAL_DECORATING_ENABLED = "true"
    NEW_RELIC_LOG_LEVEL                                   = "info"
  }
}

# ── Mailpit (SMTP interno compartilhado) ──────────────────────────────────
resource "kubernetes_deployment" "mailpit" {
  metadata {
    name      = "smtp-deployment"
    namespace = kubernetes_namespace.gearflow.metadata[0].name
    labels = {
      app = "smtp"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "smtp"
      }
    }

    template {
      metadata {
        labels = {
          app = "smtp"
        }
      }

      spec {
        container {
          name  = "mailpit"
          image = "axllent/mailpit:latest"

          port {
            container_port = 1025
            name           = "smtp"
          }
          port {
            container_port = 8025
            name           = "ui"
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "200m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mailpit" {
  metadata {
    name      = "smtp-service"
    namespace = kubernetes_namespace.gearflow.metadata[0].name
  }

  spec {
    selector = {
      app = "smtp"
    }
    type = "ClusterIP"

    port {
      name        = "smtp"
      port        = 1025
      target_port = 1025
      protocol    = "TCP"
    }
    port {
      name        = "ui"
      port        = 8025
      target_port = 8025
      protocol    = "TCP"
    }
  }
}
