# ── Alertas New Relic (requisito Fase 3 — monitoramento) ───────────────────
# Cobre os 5 itens exigidos:
#   1. Latência das APIs               → api_latency
#   2. Recursos do Kubernetes (CPU/mem)→ k8s_cpu / k8s_memory
#   3. Healthcheck e uptime            → synthetics_monitor.healthcheck + healthcheck_down
#   4. Falhas no processamento de OS   → service_order_processing_errors
#   5. Logs estruturados (JSON) com correlação → não gera alerta (ver
#      gearflow-app/docs/architecture/OBSERVABILITY.md); consumido via
#      NEW_RELIC_APPLICATION_LOGGING_FORWARDING_ENABLED (app.tf).
#
# Métricas de negócio (integration.errors, http.server.request.duration) chegam
# via OTLP — ver ObservabilityExtensions/BusinessMetrics no gearflow-app.
# Métricas de cluster (K8sContainerSample) vêm do nri-bundle (monitoring.tf).

# ── Canal de notificação (e-mail) ──────────────────────────────────────────
resource "newrelic_notification_destination" "email" {
  name = "gearflow-alertas-email"
  type = "EMAIL"

  property {
    key   = "email"
    value = var.newrelic_alert_email
  }
}

resource "newrelic_notification_channel" "email" {
  name           = "gearflow-alertas-email-channel"
  type           = "EMAIL"
  destination_id = newrelic_notification_destination.email.id
  product        = "IINT"

  property {
    key   = "subject"
    value = "[GearFlow] {{issueTitle}}"
  }
}

resource "newrelic_alert_policy" "gearflow" {
  name                = "GearFlow — Fase 3"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

resource "newrelic_workflow" "gearflow" {
  name                  = "GearFlow — notificação por e-mail"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "gearflow-policy-filter"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = [newrelic_alert_policy.gearflow.id]
    }
  }

  destination {
    channel_id = newrelic_notification_channel.email.id
  }
}

# ── 1. Latência das APIs ────────────────────────────────────────────────────
# http.server.request.duration (histograma OTel, segundos) — instrumentação
# ASP.NET Core em ObservabilityExtensions.AddObservability.
resource "newrelic_nrql_alert_condition" "api_latency" {
  policy_id                    = newrelic_alert_policy.gearflow.id
  name                         = "Latência das APIs acima do esperado (p95)"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600
  fill_option                  = "none"

  nrql {
    query = "SELECT percentile(http.server.request.duration, 95) FROM Metric WHERE service.name = 'GearFlow.Api'"
  }

  critical {
    operator              = "above"
    threshold             = 1
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }

  warning {
    operator              = "above"
    threshold             = 0.5
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

# ── 2. Consumo de recursos do Kubernetes ───────────────────────────────────
# K8sContainerSample vem do nri-bundle (newrelic-infrastructure) instalado
# no cluster via monitoring.tf.
resource "newrelic_nrql_alert_condition" "k8s_cpu" {
  policy_id                    = newrelic_alert_policy.gearflow.id
  name                         = "Kubernetes — CPU do container acima de 80%"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600
  fill_option                  = "none"

  nrql {
    query = "SELECT average(cpuCoresUtilization) FROM K8sContainerSample WHERE clusterName = '${var.cluster_name}' AND namespaceName = 'gearflow' FACET podName"
  }

  critical {
    operator              = "above"
    threshold             = 80
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

resource "newrelic_nrql_alert_condition" "k8s_memory" {
  policy_id                    = newrelic_alert_policy.gearflow.id
  name                         = "Kubernetes — Memória do container acima de 80%"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600
  fill_option                  = "none"

  nrql {
    query = "SELECT average(memoryWorkingSetUtilization) FROM K8sContainerSample WHERE clusterName = '${var.cluster_name}' AND namespaceName = 'gearflow' FACET podName"
  }

  critical {
    operator              = "above"
    threshold             = 80
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

# ── 3. Healthcheck e uptime ─────────────────────────────────────────────────
# Monitor sintético externo batendo em /health/ready (checa também o SQL
# Server — ver HealthCheckExtensions.cs), independente do cluster estar de pé.
# Aponta para o hostname real do ELB do Kong (data.kubernetes_service.kong_gateway_proxy
# em api-gateway.tf) — não há domínio próprio/Route53 provisionado para o projeto, então
# usar um domínio fictício deixaria esse monitor falhando para sempre. Rota /health
# liberada anonimamente no Ingress (k8s/api-gateway/ingress.yaml).
resource "newrelic_synthetics_monitor" "healthcheck" {
  name              = "GearFlow — /health/ready"
  type              = "SIMPLE"
  status            = "ENABLED"
  locations_public  = ["US_EAST_1"]
  period            = "EVERY_5_MINUTES"
  uri               = "http://${data.kubernetes_service.kong_gateway_proxy.status[0].load_balancer[0].ingress[0].hostname}/health/ready"
  verify_ssl        = false
  validation_string = "\"status\":\"Healthy\""

  custom_header {
    name  = "Accept"
    value = "application/json"
  }
}

resource "newrelic_nrql_alert_condition" "healthcheck_down" {
  policy_id                    = newrelic_alert_policy.gearflow.id
  name                         = "Healthcheck indisponível (/health/ready)"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600
  fill_option                  = "none"

  nrql {
    query = "SELECT filter(count(*), WHERE result != 'SUCCESS') FROM SyntheticCheck WHERE monitorName = 'GearFlow — /health/ready'"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "AT_LEAST_ONCE"
  }
}

# ── 4. Falhas no processamento de Ordens de Serviço ────────────────────────
# integration.errors{source} — incrementado nos handlers de Workshop quando
# uma porta cross-BC falha durante o ciclo de vida da OS (ex.: consumo de
# estoque na finalização). Ver FinalizeServiceOrderHandler/BusinessMetrics.
resource "newrelic_nrql_alert_condition" "service_order_processing_errors" {
  policy_id                    = newrelic_alert_policy.gearflow.id
  name                         = "Falhas no processamento de Ordens de Serviço"
  type                         = "static"
  enabled                      = true
  violation_time_limit_seconds = 3600
  fill_option                  = "static"
  fill_value                   = 0

  nrql {
    query = "SELECT sum(integration.errors) FROM Metric WHERE service.name = 'GearFlow.Api' FACET source"
  }

  critical {
    operator              = "above"
    threshold             = 0
    threshold_duration    = 300
    threshold_occurrences = "AT_LEAST_ONCE"
  }
}
