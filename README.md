# gearflow-infra-k8s

Infraestrutura Kubernetes da plataforma GearFlow. Provisiona o cluster EKS na AWS, o API Gateway (Kong), o monitoramento (New Relic) e os recursos compartilhados do namespace `gearflow` via Terraform.

> **Parte do ecossistema GearFlow** — este repositório é o **Repo 2** da arquitetura multi-repositório.
> A ordem de apply obrigatória é: `gearflow-infra-database` → `gearflow-lambda` → **`gearflow-infra-k8s`** → `gearflow-app`.

---

## Tecnologias

| Ferramenta | Uso |
|---|---|
| Terraform >= 1.6 | Provisionamento de toda a infraestrutura |
| AWS EKS | Cluster Kubernetes gerenciado |
| AWS VPC | Rede isolada para o cluster |
| Kong Ingress Controller | API Gateway (roteamento + JWT + rate-limit) |
| New Relic nri-bundle | Monitoramento e observabilidade do cluster |
| Helm | Instalação de Kong e New Relic |
| GitHub Actions | CI/CD (plan no PR, apply no merge) |

---

## Arquitetura

```
Internet
    │
    ▼
┌─────────────────────────────────────────┐
│           Kong API Gateway              │
│  /auth/* → Lambda Proxy (Repo 1)        │
│  /api/*  → gearflow-api (Repo 4)        │
│  Plugin JWT: valida token em /api/*     │
│  Plugin Rate-limit: 10 req/min em /auth │
└────────────────┬────────────────────────┘
                 │
         ┌───────┴────────┐
         ▼                ▼
  ┌─────────────┐   ┌──────────────────┐
  │   Lambdas   │   │  gearflow-api    │
  │  (Repo 1)   │   │  (Repo 4)        │
  └──────┬──────┘   └────────┬─────────┘
         │                   │
         ▼                   ▼
  ┌─────────────────────────────────────┐
  │   Banco Gerenciado (Repo 3)         │
  │   AWS RDS / SQL Server              │
  └─────────────────────────────────────┘
         │
         ▼
  ┌─────────────────────────────────────┐
  │   New Relic                         │
  │   APM + Infra + Kubernetes metrics  │
  └─────────────────────────────────────┘
```

---

## Estrutura do Repositório

```
gearflow-infra-k8s/
├── terraform/
│   ├── main.tf           # Providers: AWS, Kubernetes, Helm
│   ├── cluster.tf        # Módulo EKS + VPC
│   ├── app.tf            # Secret, ConfigMap e Mailpit do namespace gearflow
│   ├── image.tf          # Referência à imagem Docker (gerenciada pelo Repo 4)
│   ├── variables.tf      # Inputs: cluster, banco (Repo 3), lambdas (Repo 1)
│   ├── outputs.tf        # Endpoints do cluster e API Gateway
│   ├── api-gateway.tf    # Kong via Helm + ExternalName para Lambdas
│   └── monitoring.tf     # New Relic nri-bundle via Helm
├── k8s/
│   ├── gearflow/         # Manifests do namespace da aplicação
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   ├── newrelic-apm-secret.yaml
│   │   └── smtp/         # Mailpit (SMTP interno)
│   ├── monitoring/       # New Relic nri-bundle (Helm values + secrets)
│   └── api-gateway/      # Kong Ingress + plugins JWT e rate-limit
└── .github/workflows/
    ├── terraform-plan.yml   # Roda no PR: init + validate + plan
    └── terraform-apply.yml  # Roda no merge para main: apply automático
```

---

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configurado com credenciais
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) >= 3
- Conta no [Terraform Cloud](https://app.terraform.io) — organização `gearflowfiap`, workspace `gearflow-infra-k8s`

---

## Variáveis necessárias

### Secrets (valores sensíveis — nunca commitar)

| Variável | Descrição | Origem |
|---|---|---|
| `TF_API_TOKEN` | Token do Terraform Cloud | Terraform Cloud |
| `AWS_ACCESS_KEY_ID` | Credencial AWS | AWS IAM |
| `AWS_SECRET_ACCESS_KEY` | Credencial AWS | AWS IAM |
| `JWT_SIGNING_KEY` | Chave de assinatura JWT | Combinado com Repos 1 e 4 |
| `DB_PASSWORD` | Senha do banco gerenciado | Repo 3 |
| `NEWRELIC_LICENSE_KEY` | License key do New Relic | New Relic UI → API Keys |

### Variables (valores não sensíveis)

| Variável | Descrição | Origem |
|---|---|---|
| `AWS_REGION` | Região AWS (ex: `us-east-1`) | — |
| `DB_ENDPOINT` | Endpoint do banco gerenciado | Output do Repo 3 |
| `DB_PORT` | Porta do banco (ex: `1433`) | Output do Repo 3 |
| `DB_NAME` | Nome do banco (ex: `GearFlowDb`) | Output do Repo 3 |
| `DB_USER` | Usuário da aplicação no banco | Output do Repo 3 |
| `LAMBDA_VALIDATE_CPF_URL` | URL da Lambda validate-cpf | Output do Repo 1 |
| `LAMBDA_CHECK_CLIENT_URL` | URL da Lambda check-client | Output do Repo 1 |
| `LAMBDA_GENERATE_TOKEN_URL` | URL da Lambda generate-token | Output do Repo 1 |

---

## Deploy

### Local (validação)

```bash
cd terraform

# Inicializa sem conectar ao backend remoto
terraform init -backend=false

# Valida sintaxe e referências
terraform validate
```

### Via CI/CD (fluxo normal)

1. Criar uma branch a partir de `main`
2. Fazer as alterações desejadas
3. Abrir um Pull Request → o pipeline `terraform-plan.yml` roda automaticamente e posta o plano como comentário no PR
4. Após aprovação e merge → o pipeline `terraform-apply.yml` aplica as mudanças automaticamente

### Apply manual (primeira vez ou emergência)

```bash
cd terraform

terraform init
terraform apply

# Aponta o kubectl para o cluster criado
aws eks update-kubeconfig --region us-east-1 --name gearflow
```

### Aplicar manifests Kubernetes manualmente

```bash
# Namespace e recursos compartilhados
kubectl apply -f k8s/gearflow/namespace.yaml
kubectl apply -f k8s/gearflow/

# Monitoramento
kubectl apply -f k8s/monitoring/namespace.yaml
kubectl apply -f k8s/monitoring/secret.yaml
helm repo add newrelic https://helm-charts.newrelic.com
helm install nri-bundle newrelic/nri-bundle -n newrelic -f k8s/monitoring/helm-values.yaml \
  --set global.licenseKey=<LICENSE_KEY>

# API Gateway (Kong deve estar instalado via Terraform antes)
kubectl apply -f k8s/api-gateway/
```

---

## Acessos úteis em desenvolvimento

```bash
# Painel de e-mails Mailpit
kubectl port-forward svc/smtp-service 8025:8025 -n gearflow
# Acesse: http://localhost:8025

# Endpoint público do Kong (API Gateway)
kubectl get svc -n kong kong-gateway-proxy
```

---

## Repositórios relacionados

| Repositório | Responsabilidade | Ordem de apply |
|---|---|---|
| [gearflow-infra-database](../gearflow-infra-database) | Banco de dados gerenciado (Terraform) | 1º |
| [gearflow-lambda](../gearflow-lambda) | Funções serverless de autenticação | 2º |
| **gearflow-infra-k8s** | Cluster EKS + API Gateway + Monitoramento | **3º** |
| [gearflow-app](../gearflow-app) | Aplicação .NET no Kubernetes | 4º |