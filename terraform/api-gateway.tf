# ── Kong Ingress Controller ───────────────────────────────────────────────
resource "helm_release" "kong" {
  name             = "kong"
  repository       = "https://charts.konghq.com"
  chart            = "ingress"
  namespace        = "kong"
  create_namespace = true
  version          = "~> 0.4"
  timeout          = 600
  wait             = false

  set {
    name  = "gateway.service.type"
    value = "LoadBalancer"
  }

  depends_on = [aws_eks_node_group.default]
}

# Hostname real do ELB criado pelo Service LoadBalancer do Kong — só existe depois do
# helm_release.kong provisionar. Usado pelo monitor de uptime do New Relic (newrelic-alerts.tf)
# em vez de um domínio fictício.
data "kubernetes_service" "kong_gateway_proxy" {
  metadata {
    name      = "kong-gateway-proxy"
    namespace = "kong"
  }

  depends_on = [helm_release.kong]
}

# ── Namespace para o proxy das Lambdas ────────────────────────────────────
resource "kubernetes_namespace" "lambda_proxy" {
  metadata {
    name = "lambda-proxy"
  }
  depends_on = [aws_eks_node_group.default]
}

# ── Service apontando para as Lambdas via ExternalName ────────────────────
# Roteia /auth/* para o API Gateway das Lambdas (gearflow-lambda)
resource "kubernetes_service" "lambda_proxy" {
  metadata {
    name      = "lambda-proxy-svc"
    namespace = kubernetes_namespace.gearflow.metadata[0].name
    annotations = {
      "konghq.com/protocol" = "https"
    }
  }

  spec {
    type = "ExternalName"
    # Domínio base do API Gateway AWS que expõe as Lambdas (sem path)
    external_name = regex("https?://([^/]+)", var.lambda_check_client_url)[0]
  }
}
