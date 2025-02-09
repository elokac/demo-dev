terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.32.0"
    }
  }
}

provider "kubernetes" {
    config_path    = "../kubeconfig"
    config_context = "demo-dev"
}

provider "helm" {
  kubernetes {
    config_path = "../kubeconfig"
  }
}