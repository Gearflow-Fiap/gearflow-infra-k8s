# ── New Relic nri-bundle via Helm ─────────────────────────────────────────
resource "helm_release" "newrelic" {
  name             = "nri-bundle"
  repository       = "https://helm-charts.newrelic.com"
  chart            = "nri-bundle"
  namespace        = "newrelic"
  create_namespace = true

  set {
    name  = "global.licenseKey"
    value = var.newrelic_license_key
  }

  set {
    name  = "global.cluster"
    value = var.cluster_name
  }

  set {
    name  = "global.lowDataMode"
    value = "true"
  }

  set {
    name  = "newrelic-infrastructure.enabled"
    value = "true"
  }

  set {
    name  = "kube-state-metrics.enabled"
    value = "true"
  }

  set {
    name  = "nri-kube-events.enabled"
    value = "true"
  }

  set {
    name  = "nri-prometheus.enabled"
    value = "true"
  }

  # Fluent Bit: o APM .NET já encaminha logs diretamente
  set {
    name  = "newrelic-logging.enabled"
    value = "false"
  }

  depends_on = [module.eks]
}
