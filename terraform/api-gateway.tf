# ── Kong Ingress Controller ───────────────────────────────────────────────
resource "helm_release" "kong" {
  name             = "kong"
  repository       = "https://charts.konghq.com"
  chart            = "ingress"
  namespace        = "kong"
  create_namespace = true
  version          = "~> 0.4"

  set {
    name  = "gateway.service.type"
    value = "LoadBalancer"
  }

  depends_on = [module.eks]
}

# ── Namespace para o proxy das Lambdas ────────────────────────────────────
resource "kubernetes_namespace" "lambda_proxy" {
  metadata {
    name = "lambda-proxy"
  }
  depends_on = [module.eks]
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
    type          = "ExternalName"
    # Domínio base do API Gateway AWS que expõe as Lambdas (sem path)
    external_name = regex("https?://([^/]+)", var.lambda_check_client_url)[0]
  }
}
