# Architecture

## GitOps Flow

```
Engineer pushes to Git
         │
         ▼
GitHub Repository
  apps/staging/   ← desired state for staging
  apps/production/ ← desired state for production
         │
         │ ArgoCD polls every 180 seconds
         ▼
ArgoCD Application Controller
  ├── renders manifests via Kustomize
  ├── compares rendered output vs cluster state
  └── if different: applies diff to cluster
         │
         ▼
Kubernetes Cluster
  staging    → 1 replica
  production → 2 replicas
```

## Self-Heal Flow

```
kubectl scale deployment api-service -n production --replicas=5
         │
         ▼
Cluster state: 5 replicas
Git state:     2 replicas
         │
         ▼
ArgoCD detects mismatch (continuous watch)
         │
         ▼
ArgoCD applies Git state
         │
         ▼
Cluster state: 2 replicas
Time: under 2 seconds
```

## Component Roles

ArgoCD Application Controller:
- Compares desired (Git) vs actual (cluster) continuously
- Triggers sync on mismatch

ArgoCD Repo Server:
- Clones Git repository
- Renders Kustomize manifests

ArgoCD API Server:
- Serves web UI and CLI
- Enforces RBAC from AppProject

ApplicationSet Controller:
- Reads ApplicationSet resources
- Runs matrix generator
- Creates and manages Application resources

Argo Rollouts Controller:
- Manages Rollout resources
- Controls canary traffic weight
- Promotes or aborts based on configured steps

---

## Kustomize Overlay Design

```
apps/base/deployment.yaml
  image: nginx:1.25-alpine
  replicas: 2
  securityContext: runAsNonRoot: true
  readinessProbe configured
  resource limits set

apps/staging/kustomization.yaml
  patches:
    - replicas: 1          ← only difference
  commonLabels:
    environment: staging

apps/production/kustomization.yaml
  commonLabels:
    environment: production
  # inherits 2 replicas from base
```

Why copy base into each overlay rather than reference it:
ArgoCD blocks cross-directory Kustomize references for security.
../base/deployment.yaml is not allowed from within an overlay path.
Files must be local to the overlay directory.

---

## Sync Wave Ordering

```
Wave 0: Namespace         — must exist before anything else
Wave 1: ConfigMap/Service — config before application
Wave 2: Deployment        — application after config
Wave 3: Rollout           — canary routing after stable deployment
```

ArgoCD waits for all resources in a wave to be healthy
before starting the next wave.

---

## Terraform Provisions ArgoCD

```hcl
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  version    = "7.3.11"
}

resource "helm_release" "argo_rollouts" {
  name    = "argo-rollouts"
  chart   = "argo-rollouts"
}
```

The GitOps tool itself is defined as infrastructure code.
Terraform provisions ArgoCD. ArgoCD manages everything else.
Full IaC + GitOps story from one codebase.
