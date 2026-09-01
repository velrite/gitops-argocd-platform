# GitOps Model

## Core Principle

Git repository = desired state of the system
Cluster = actual state of the system
ArgoCD continuously makes actual match desired

Same reconciliation loop as Kubernetes — one level up:
- Kubernetes reconciles pods to match Deployment specs
- ArgoCD reconciles cluster resources to match Git manifests

## How Sync Works

1. ArgoCD polls Git every 180 seconds
2. Repo Server clones and renders Kustomize manifests
3. Application Controller compares rendered output vs cluster
4. If different: computes diff, applies changed resources only
5. Reports sync status

With automated: true — steps 4 and 5 happen without human action.
With selfHeal: true — sync also fires when cluster drifts from Git.

## Sync Policy

```yaml
syncPolicy:
  automated:
    prune: true      # delete resources removed from Git
    selfHeal: true   # correct manual cluster changes
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

prune: true means deleting a manifest from Git
deletes the corresponding resource from cluster.
Git is the complete record — nothing runs that is not in Git.

## Rollback Model

Wrong way:
```bash
kubectl rollout undo deployment/api-service -n production
```

GitOps way:
```bash
git revert HEAD
git push
```

ArgoCD detects revert, renders previous manifests, applies to cluster.
Full audit trail in Git history. Every change traceable.

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

2 environments × 1 app = 2 Applications generated automatically.
staging-api-service and production-api-service.
Add environment: one line. Add app: one line.
