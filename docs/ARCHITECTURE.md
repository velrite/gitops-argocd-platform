# Architecture

## GitOps Flow

```
Engineer pushes to Git
         │
         ▼
GitHub Repository
  apps/staging/kustomization.yaml   ← desired state for staging
  apps/production/kustomization.yaml ← desired state for production
         │
         │ ArgoCD polls every 180 seconds
         ▼
ArgoCD Application Controller
  ├── renders manifests via Kustomize
  ├── compares rendered manifests vs cluster state
  └── if different: syncs (applies diff to cluster)
         │
         ▼
Kubernetes Cluster
  staging namespace   → 1 replica of api-service
  production namespace → 2 replicas of api-service
```

## Self-Heal Flow

```
Engineer runs: kubectl scale deployment api-service -n production --replicas=5
         │
         ▼
Cluster state: 5 replicas
Git state:     2 replicas
         │
         ▼
ArgoCD detects mismatch (continuous watch)
         │
         ▼
ArgoCD applies Git state to cluster
         │
         ▼
Cluster state: 2 replicas (corrected)
Total time: under 2 seconds
```

## Component Roles

### ArgoCD Application Controller
- Compares desired state (Git) vs actual state (cluster) continuously
- Triggers sync when mismatch detected
- Reports sync status and health status per application

### ArgoCD Repo Server
- Clones Git repository
- Renders Kustomize manifests
- Returns rendered manifests to Application Controller for comparison

### ArgoCD API Server
- Serves the web UI
- Handles CLI authentication
- Enforces RBAC policies from AppProject

### ApplicationSet Controller
- Reads ApplicationSet resources
- Runs matrix generator across environments and apps lists
- Creates and manages individual Application resources

### Argo Rollouts Controller
- Manages Rollout resources (canary deployments)
- Controls traffic weight between stable and canary versions
- Promotes or aborts based on configured steps and analysis

---

## Kustomize Overlay Design

Base manifest defines the application once.
Each environment overlay patches only what differs.

```
apps/base/deployment.yaml
  image: nginx:1.25-alpine
  replicas: 2
  resources: requests cpu 50m, memory 64Mi
             limits  cpu 200m, memory 128Mi
  readinessProbe: httpGet / port 80
  securityContext: runAsNonRoot: true

apps/staging/kustomization.yaml
  patches:
    - replicas: 1              ← only difference from base
  commonLabels:
    environment: staging

apps/production/kustomization.yaml
  commonLabels:
    environment: production
  # replicas not patched — inherits 2 from base
```

Why copy base into each overlay rather than reference it:
ArgoCD's Kustomize security model blocks cross-directory references
(../base/deployment.yaml). Files must be local to the overlay directory.

---

## Sync Wave Ordering

```yaml
# Deployed first — namespace must exist before anything else
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"

# Deployed second — config before application starts
apiVersion: v1
kind: ConfigMap
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"

# Deployed third — application uses config from wave 1
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"

# Deployed last — canary routing after stable deployment exists
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "3"
```

ArgoCD waits for all resources in a wave to be healthy before
proceeding to the next wave.

---

## Terraform Provisions ArgoCD

ArgoCD itself is installed via Terraform in Project 2 pattern:

```hcl
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  version    = "7.3.11"
}

resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  namespace  = "argocd"
}
```

This completes the IaC + GitOps story:
- Terraform defines the GitOps tool as code (Project 2 pattern)
- The GitOps tool manages all application deployments
- Infrastructure and applications both managed declaratively

