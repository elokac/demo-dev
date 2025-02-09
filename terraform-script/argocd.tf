resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = "argocd"
  chart      = "argocd"
  version    = "3.23.0"
  repository = "https://argoproj.github.io/argo-helm"
}