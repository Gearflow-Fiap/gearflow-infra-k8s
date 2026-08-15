terraform {
  required_version = ">= 1.6"

  cloud {
    organization = "gearflowfiapmurilo"

    workspaces {
      name = "gearflow-infra-k8s"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster_auth" "gearflow" {
  name = aws_eks_cluster.gearflow.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.gearflow.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.gearflow.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.gearflow.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.gearflow.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.gearflow.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.gearflow.token
  }
}
