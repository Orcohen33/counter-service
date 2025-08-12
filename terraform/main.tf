provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  kubernetes_version = "1.32"
  name               = var.cluster_name

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  # EKS Managed Node Group
  eks_managed_node_groups = {
    main = {
      subnet_ids   = module.vpc.private_subnets
      desired_size = var.node_group_desired_size
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size

      instance_types = [var.node_instance_type]

      capacity_type = "ON_DEMAND"

      update_config = {
        max_unavailable_percentage = 33
      }

      tags = {
        Environment = var.environment
        Terraform   = "true"
      }
    }
  }

  # Enable IRSA
  enable_irsa = true

  # Add-ons
  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }

  # IAM Role for EKS

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# IAM role for EBS CSI Driver
data "aws_iam_policy_document" "ebs_csi_policy" {
  statement {
    actions = [
      "ec2:CreateSnapshot",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
      "ec2:ModifyVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeSnapshots",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
      "ec2:DescribeVolumeStatus",
      "ec2:DescribeVolumeAttribute",
      "ec2:DescribeTags",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:DeleteSnapshot"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:CreateSnapshot"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateVolumePermission"
      values   = ["true"]
    }
  }
}

resource "aws_iam_policy" "ebs_csi_policy" {
  name        = "${var.cluster_name}-ebs-csi-policy"
  description = "IAM policy for EBS CSI driver"
  policy      = data.aws_iam_policy_document.ebs_csi_policy.json

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# IRSA role for EBS CSI driver
module "ebs_csi_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name             = "${var.cluster_name}-ebs-csi-driver"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
}

# Update kubeconfig
resource "null_resource" "kubectl" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = "aws eks --region ${var.region} update-kubeconfig --name ${var.cluster_name}"
  }
}

# Install Metrics Server
resource "helm_release" "metrics_server" {
  depends_on = [module.eks]

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.11.0"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}


# Install NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  depends_on = [module.eks]

  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.13.0"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }
}


# Install ArgoCD
resource "helm_release" "argocd" {
  depends_on = [module.eks]

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "8.2.7"
  values = [
    file("${path.module}/values/argocd-values.yaml")
  ]
}
