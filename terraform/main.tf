terraform {
  required_version = ">= 1.7.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "prod-sim"
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "prod-sim"
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      managed-by  = "terraform"
      environment = "platform"
    }
  }
}

resource "kubernetes_namespace" "staging" {
  metadata {
    name = "staging"
    labels = {
      managed-by  = "terraform"
      environment = "staging"
    }
  }
}

resource "kubernetes_namespace" "production" {
  metadata {
    name = "production"
    labels = {
      managed-by  = "terraform"
      environment = "production"
    }
  }
}

resource "kubernetes_namespace" "argo_rollouts" {
  metadata {
    name = "argo-rollouts"
    labels = {
      managed-by = "terraform"
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.3.11"
  timeout    = 600

  values = [file("${path.module}/argocd-values.yaml")]

  depends_on = [kubernetes_namespace.argocd]
}

resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  namespace  = kubernetes_namespace.argo_rollouts.metadata[0].name
  timeout    = 300

  set {
    name  = "dashboard.enabled"
    value = "true"
  }

  depends_on = [kubernetes_namespace.argo_rollouts]
}