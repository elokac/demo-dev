resource "kubernetes_namespace" "argocd" {
  metadata {
    annotations = {
      name = "k3s-cluster"
    }

    labels = {
      managedby = "terraform"
    }

    name = "argocd"
  }
}