# ── Dashboard custom GearFlow (requisito Fase 3) ───────────────────────────
# As métricas de negócio chegam via OTLP (Meter "GearFlow.Business",
# ObservabilityExtensions no gearflow-app) e ficam disponíveis como `Metric`
# no New Relic. Ver gearflow-app/docs/architecture/OBSERVABILITY.md.
resource "newrelic_one_dashboard" "gearflow" {
  name        = "GearFlow — Fase 3"
  permissions = "public_read_only"

  page {
    name = "Ordens de Serviço"

    widget_line {
      title  = "Volume diário de Ordens de Serviço"
      row    = 1
      column = 1
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM Metric SELECT sum(serviceorders.created) AS 'OS criadas' TIMESERIES 1 day SINCE 30 days ago"
      }
    }

    widget_bar {
      title  = "Tempo médio de execução por status"
      row    = 1
      column = 5
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM Metric SELECT average(serviceorder.status.duration) FACET status SINCE 7 days ago"
      }
    }

    widget_bar {
      title  = "Erros/falhas nas integrações"
      row    = 1
      column = 9
      width  = 4
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM Metric SELECT sum(integration.errors) FACET source SINCE 7 days ago"
      }
    }
  }

  # Página adicional: latência das APIs, recursos do Kubernetes e uptime
  # (requisito Fase 3 — ver newrelic-alerts.tf para os alertas correspondentes).
  page {
    name = "Infraestrutura & Performance"

    widget_line {
      title  = "Latência das APIs (p50/p95/p99)"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM Metric SELECT percentile(http.server.request.duration, 50, 95, 99) WHERE service.name = 'GearFlow.Api' TIMESERIES SINCE 3 hours ago"
      }
    }

    widget_billboard {
      title  = "Healthcheck — uptime (/health/ready)"
      row    = 1
      column = 7
      width  = 3
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM SyntheticCheck SELECT percentage(count(*), WHERE result = 'SUCCESS') AS 'Uptime %' WHERE monitorName = 'GearFlow — /health/ready' SINCE 1 day ago"
      }
    }

    widget_line {
      title  = "Kubernetes — CPU por pod (namespace gearflow)"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sContainerSample SELECT average(cpuCoresUtilization) FACET podName WHERE clusterName = '${var.cluster_name}' AND namespaceName = 'gearflow' TIMESERIES SINCE 3 hours ago"
      }
    }

    widget_line {
      title  = "Kubernetes — Memória por pod (namespace gearflow)"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = "FROM K8sContainerSample SELECT average(memoryWorkingSetUtilization) FACET podName WHERE clusterName = '${var.cluster_name}' AND namespaceName = 'gearflow' TIMESERIES SINCE 3 hours ago"
      }
    }
  }
}
