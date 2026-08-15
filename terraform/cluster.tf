# ── VPC ──────────────────────────────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# ── EKS Cluster ───────────────────────────────────────────────────────────
# Usando recursos nativos para evitar iam:GetRole bloqueado no AWS Academy
resource "aws_eks_cluster" "gearflow" {
  name     = var.cluster_name
  version  = "1.31"
  role_arn = "arn:aws:iam::269224082939:role/LabRole"

  vpc_config {
    subnet_ids              = module.vpc.private_subnets
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  depends_on = [module.vpc]
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.gearflow.name
  node_group_name = "default"
  node_role_arn   = "arn:aws:iam::269224082939:role/LabRole"
  subnet_ids      = module.vpc.private_subnets
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = 1
    max_size     = 3
    min_size     = 1
  }

  depends_on = [aws_eks_cluster.gearflow]
}

# ── Namespaces ────────────────────────────────────────────────────────────

resource "kubernetes_namespace" "gearflow" {
  metadata {
    name = "gearflow"
  }
  depends_on = [aws_eks_node_group.default]
}
