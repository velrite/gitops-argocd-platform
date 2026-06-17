
# GitOps Platform — ArgoCD on Kubernetes

A production-oriented GitOps platform where Git is the single source
of truth and the cluster continuously proves it.

This project addresses a fundamental operational problem: imperative
kubectl workflows leave no immutable audit trail, allow silent
configuration drift, and create fragile deployment processes that
degrade under pressure.

GitOps inverts that model entirely.

---

## Core Engineering Principle

> Git is not a deployment trigger.
> Git is the desired state of the platform.
> The cluster's only job is to continuously prove it.

---

## Architecture

```
GitHub Repository (Source of Truth)
        │
        │  ArgoCD polls every 3 minutes
        │  or instantly via webhook
        ▼
┌─────────────────────────────────────────────┐
│              ArgoCD (namespace: argocd)     │
│                                             │
│  Application Controller                     │
│  — compares Git state vs cluster state      │
│                                             │
│  Repo Server                                │
│  — pulls and renders manifests (Kustomize)  │
│                                             │
│  API Server                                 │
│  — UI and CLI access                        │
│                                             │
│  ApplicationSet Controller                  │
│  — generates Applications per environment  │
└──────────────────┬──────────────────────────┘
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
staging-api-service    production-api-service
(namespace: staging)   (namespace: production)
2 replicas             2 replicas
                       canary via Argo Rollouts
```

### The Core Reconciliation Loop

```
Desired State (Git)
        │
        ▼
   ArgoCD compares
        │
        ▼
Actual State (Cluster)
        │
        ▼
  If different →
  ArgoCD corrects cluster automatically
        │
        ▼
  Loop runs continuously
```

This is the same reconciliation pattern as Kubernetes itself.
Kubernetes reconciles pods to match Deployments.
ArgoCD reconciles the cluster to match Git.
Same loop — one layer higher.

---

## Component Breakdown

| Component | Role |
|-----------|------|
| Terraform | Provisions ArgoCD and Argo Rollouts onto the cluster — IaC layer |
| ArgoCD | Watches Git, syncs cluster to match it, self-heals drift |
| Kustomize Overlays | One base manifest patched per environment — staging 1 replica, production 2 |
| AppProject | RBAC boundary — defines who can sync what and where apps are allowed to deploy |
| ApplicationSet | Generates staging and production Applications from one template via matrix generator |
| Argo Rollouts | Canary deployment engine — shifts traffic gradually instead of all at once |
| Sync Waves | Controls deployment order — namespace and configmap before deployment |

---

## What This Platform Addresses

**Configuration Drift**
Any manual cluster modification is detected within seconds
and automatically reconciled back to the declared Git state.
The cluster cannot silently diverge from what was intended.

**Deployment Auditability**
Deployment history maps directly to git log.
Every change is reviewed before it reaches the cluster.
Rollback is git revert — no scripts, no manual intervention.

**Deployment Safety**
Progressive delivery via Argo Rollouts.
Canary deployments promoted or rolled back automatically
based on real-time Prometheus SLO thresholds.
Bad deployments never reach full production traffic.

**Secrets Management**
HashiCorp Vault injects credentials dynamically at runtime.
No secrets stored in Git under any circumstances.
Static credentials eliminated from all environments.

---

## Proven Results

- ArgoCD drift detection and auto-reconciliation confirmed
- Manual kubectl scale command corrected in under 2 seconds
- Both staging and production applications Synced and Healthy
- CI/CD pipeline passing all stages automatically
- Multi-environment GitOps workflow validated end to end

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| GitOps Engine | ArgoCD |
| Progressive Delivery | Argo Rollouts |
| Container Orchestration | Kubernetes |
| Manifest Templating | Kustomize |
| Infrastructure as Code | Terraform |
| Monitoring | Prometheus + Grafana |
| Alerting | Alertmanager |
| Secrets Management | HashiCorp Vault |
| CI Pipeline | GitHub Actions |
| Container Registry | GHCR |

---

## Repository Structure

```
gitops-argocd-platform/
├── apps/
│   ├── base/
│   │   └── api-service.yaml
│   ├── staging/
│   │   └── kustomization.yaml
│   └── production/
│       └── kustomization.yaml
├── argocd/
│   ├── install/
│   ├── applications/
│   ├── appsets/
│   └── projects/
├── rollouts/
│   ├── canary-rollout.yaml
│   └── bluegreen-rollout.yaml
├── monitoring/
│   └── alerts/
└── terraform/
    └── argocd-install/
```

---

## Environments

| Environment | Sync Policy | Delivery Strategy | Replicas |
|-------------|-------------|------------------|----------|
| Staging | Automatic | Direct deployment | 1 |
| Production | Manual gate | Canary → Full | 2 |

---

## Deployment Workflow

1. Developer updates application manifest or image tag
2. Pull Request opened for peer review
3. Merge to main triggers ArgoCD sync detection
4. Kustomize renders environment-specific manifests
5. ArgoCD syncs cluster to declared state
6. Argo Rollouts begins canary deployment in production
7. Prometheus validates SLO thresholds continuously
8. Full promotion on success — automatic rollback on breach

---

## Drift Detection

ArgoCD continuously compares live cluster state against
declared Git state.

Any manual modification introduced directly to the cluster:

- Detected automatically within seconds
- Application marked OutOfSync
- Cluster reconciled back to Git state without intervention

Validated: manual kubectl scale command corrected
in under 2 seconds across multiple test runs.

---

## Progressive Delivery

Argo Rollouts manages controlled application promotion.

- Canary deployments with configurable traffic splitting
- Metric-based promotion driven by Prometheus SLOs
- Automated rollback on SLO breach
- Blue-green deployment support
- Sync waves control deployment ordering

Unlike native Kubernetes Deployments, promotion decisions
are driven directly from real application health metrics —
not assumptions.

---

## Secrets Management

HashiCorp Vault provides dynamic credential management:

- Dynamic credential generation per request
- Automatic secret rotation and lease management
- Centralized audit logging
- No static credentials stored anywhere

Note: Kubernetes Secrets are Base64 encoded by default
and should not be treated as a complete secrets solution
without additional encryption configuration.

---

## Failure Scenarios

| Scenario | Platform Response |
|----------|-----------------|
| Manual cluster modification | ArgoCD detects and auto-reconciles in under 2 seconds |
| Failed image deployment | Rollout halted — no traffic impact |
| Canary SLO breach | Automatic rollback triggered |
| Application sync failure | Prometheus alert generated |
| Secret expiration | Vault re-issues credential automatically |

---

## Technical Decisions

**Why ArgoCD over Flux**
ArgoCD provides ApplicationSets for multi-environment management,
AppProjects for RBAC boundaries, and immediate visibility into
drift state across all applications simultaneously.

**Why Kustomize over Helm**
Kustomize overlays allow one base manifest to be patched
differently per environment without templating complexity.
Staging and production diverge only where they need to.

**Why Argo Rollouts over native Deployments**
Native Kubernetes Deployments have no concept of metric-driven
promotion. Argo Rollouts adds SLO-gated traffic splitting,
automated analysis, and abort behavior that native rollouts
cannot provide.

**Why GitOps over push-based CI/CD**
Push-based deployments require CI systems to hold cluster
credentials — an unnecessary security surface. Pull-based
GitOps keeps deployment authority inside the cluster where
it belongs.

**Why Vault over Kubernetes Secrets**
Kubernetes Secrets are Base64 encoded — not encrypted at rest
by default. Vault provides dynamic credential generation,
automatic rotation, and audit logging that Kubernetes Secrets
cannot match.

---

## Verification Commands

```bash
# Check all ArgoCD applications
argocd app list

# Get detailed application status
argocd app get production-api-service

# Check rollout status
kubectl get rollouts -A

# Verify all workloads
kubectl get pods -A
```

---

## Lessons Learned

- GitOps reconciliation operates on a fundamentally different
  timescale than Kubernetes self-healing — drift corrected
  in under 2 seconds compared to the 20–46 seconds observed
  in node failure recovery scenarios
- Kustomize overlays enforce environment parity at the manifest
  level — configuration drift between environments becomes
  structurally impossible
- Progressive delivery requires observability to be useful —
  metric-driven promotion only works if the metrics are meaningful
- AppProjects are worth configuring from day one — retrofitting
  RBAC boundaries after deployment is significantly harder
- Secret management must be designed before the first deployment
  not retrofitted after

---

## Future Improvements

- Multi-cluster GitOps management
- Policy enforcement with Kyverno
- Service mesh integration with Istio
- Disaster recovery automation
- High availability ArgoCD deployment
- Automated compliance validation

---

## Author

Olamide Olalekan — Platform & DevSecOps Engineer

[Portfolio](https://velrite.github.io) |
[LinkedIn](https://linkedin.com/in/olamide-olalekan-12138a265) |
[GitHub](https://github.com/velrite)

---

## Related Projects

- [Auto-Healing Kubernetes Platform](https://github.com/velrite/auto-healing-kubernetes-platform)
- [Terraform Kubernetes Platform](https://github.com/velrite/Terraform-Kubernetes-Platform)
- [Dockerize-Everything](https://github.com/velrite/Dockerize-Everything)
````

---
