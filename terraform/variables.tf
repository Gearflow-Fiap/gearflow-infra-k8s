variable "aws_region" {
  description = "Região AWS onde o cluster será provisionado"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
  default     = "gearflow"
}

variable "node_instance_type" {
  description = "Tipo de instância EC2 para os nós do cluster"
  type        = string
  default     = "t3.medium"
}

variable "api_image" {
  description = "Imagem Docker da API (ex: usuario/gearflow-api:latest)"
  type        = string
  default     = "luizrodd/gearflow-api:latest"
}

variable "jwt_signing_key" {
  description = "Chave de assinatura JWT (deve ser a mesma usada pelas Lambdas do gearflow-lambda)"
  type        = string
  sensitive   = true
}

variable "smtp_ui_nodeport" {
  description = "NodePort exposto para o painel Mailpit (apenas em ambientes locais)"
  type        = number
  default     = 30025
}

# ── Inputs do gearflow-infra-database (Repo 3) ───────────────────────────

variable "db_endpoint" {
  description = "Endpoint do banco gerenciado (output do gearflow-infra-database)"
  type        = string
  default     = "localhost"
}

variable "db_port" {
  description = "Porta do banco gerenciado"
  type        = number
  default     = 1433
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "GearFlowDb"
}

variable "db_user" {
  description = "Usuário do banco de dados gerenciado"
  type        = string
  default     = "gearflow_app"
}

variable "db_password" {
  description = "Senha do usuário do banco de dados gerenciado"
  type        = string
  sensitive   = true
}

# ── Inputs do gearflow-lambda (Repo 1) ───────────────────────────────────

variable "lambda_validate_cpf_url" {
  description = "URL da Lambda validate-cpf (output do gearflow-lambda)"
  type        = string
  default     = "https://placeholder.execute-api.us-east-1.amazonaws.com/validate-cpf"
}

variable "lambda_check_client_url" {
  description = "URL da Lambda check-client (output do gearflow-lambda)"
  type        = string
  default     = "https://placeholder.execute-api.us-east-1.amazonaws.com/check-client"
}

variable "lambda_generate_token_url" {
  description = "URL da Lambda generate-token (output do gearflow-lambda)"
  type        = string
  default     = "https://placeholder.execute-api.us-east-1.amazonaws.com/generate-token"
}

variable "newrelic_license_key" {
  description = "License key do New Relic"
  type        = string
  sensitive   = true
}
