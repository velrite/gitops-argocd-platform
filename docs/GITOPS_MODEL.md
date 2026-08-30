# GitOps Model

## The Core Principle

The Git repository is the desired state of the system.
The cluster is the actual state of the system.
ArgoCD continuously makes actual match desired.

This is the same reconciliation loop as Kubernetes itself — just one level up:
- Kubernetes reconciles pods to match Deployment specs
- ArgoCD reconciles cluster resources to match Git manifests

## How Sync Works

1. ArgoCD polls the Git repository every 180 seconds
2. Repo Server clones the repo and renders Kustomize manifests
3. Application Controller compares rendered output vs cluster state
4. If different: computes diff and applies changed resources only
5. Reports sync status: Synced / OutOfSync / Unknown

With `automated: true`, steps 4 and 5 happen without human action.
With `selfHeal: true`, the sync also fires when cluster state drifts
from Git (not just when Git changes).

## Sync Policy Configuration

```yaml
syncPolicy:
  automated:
    prune: true      # delete resources removed from Git
    selfHeal: true   # correct manual cluster changes
  syncOptions:
    - CreateNamespace=true   # create namespace if missing
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

`prune: true` means if you delete a manifest from Git,
ArgoCD deletes the corresponding resource from the cluster.
This enforces Git as the complete record — nothing runs that
is not in Git.

## Rollback Model

**Wrong way:**
```bash
kubectl rollout undo deployment/api-service -n production
```

**GitOps way:**
```bash
git revert HEAD
git push
```

ArgoCD detects the revert commit, renders the previous manifests,
applies them to the cluster. Full audit trail in Git history.
Every change traceable to a commit, a time, and an author.

## ApplicationSet Matrix Generator

```yaml
generators:
  - matrix:
      generators:
        - list:
            elements:
              - environment: staging
                namespace: staging
                repoPath: apps/staging
              - environment: production
                namespace: production
                repoPath: apps/production
        - list:
            elements:
              - app: api-service
```

Matrix of 2 environments × 1 app = 2 Applications generated:
- staging-api-service
- production-api-service

To add a new environment: add one element to the first list.
To add a new app: add one element to the second list.
ApplicationSet generates all combinations automatically.

## RBAC Model

```
Platform Team (platform-admin role)
  ├── can sync any app in any namespace
  ├── can add/remove clusters
  └── can manage repositories

Dev Team (developer role)
  ├── can view all apps (read only)
  ├── can sync staging-* apps only
  └── CANNOT sync production apps directly
```

Developers push to Git → ArgoCD handles production.
This prevents manual production changes and enforces change review via PRs.

