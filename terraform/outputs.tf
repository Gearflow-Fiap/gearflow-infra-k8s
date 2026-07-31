output "cluster_name" {
  description = "Nome do cluster EKS criado"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint da API do cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "api_gateway_endpoint" {
  description = "Endpoint público do API Gateway (Kong LoadBalancer)"
  value       = "Obter via: kubectl get svc -n kong kong-gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "mailpit_ui_access" {
  description = "Acesso ao painel Mailpit via port-forward"
  value       = "kubectl port-forward svc/smtp-service 8025:8025 -n gearflow"
}

output "configure_kubectl" {
  description = "Comando para configurar o kubectl apontando para este cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
