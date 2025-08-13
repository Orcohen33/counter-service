variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "eu-west-2"
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "${var.environment}-or-cluster"
}

variable "environment" {
  description = "The environment for the deployment (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}


# ------------------------------ EKS MODULE VARIABLES -------------------------------------
variable "node_group_desired_size" {
  description = "The desired size of the EKS node group"
  type        = number
  default     = 3
}

variable "node_group_max_size" {
  description = "The maximum size of the EKS node group"
  type        = number
  default     = 5
}
variable "node_group_min_size" {
  description = "The minimum size of the EKS node group"
  type        = number
  default     = 3
}

variable "node_instance_type" {
  description = "The instance type for the EKS nodes"
  type        = string
  default     = "t3.medium"
}
