terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"

    }
  }
  # backend "s3" {
  #   bucket = "counter-terraform-state"
  #   key    = "counter-service/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.cluster.token
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  }
}
