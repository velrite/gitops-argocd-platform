# GitOps ArgoCD Platform

Git is the only source of truth. The cluster is a reflection of it.

**Author:** Olamide Olalekan — Platform & DevSecOps Engineer
**GitHub:** [github.com/velrite](https://github.com/velrite)
**LinkedIn:** [linkedin.com/in/olamide-olalekan-12138a265](https://linkedin.com/in/olamide-olalekan-12138a265)
**Email:** velrite.tech@gmail.com

---

## Why This Project Exists

In the first two projects, deployment still required a human running commands.
Even with Terraform, someone had to run `terraform apply`.
Even with kubectl, someone had to run `kubectl apply`.

This project eliminates that entirely.

Push to Git. ArgoCD detects the change and syncs the cluster.
Change the cluster manually. ArgoCD detects the drift and corrects it.
Roll back. Revert the commit. ArgoCD applies the previous state.

No kubectl in production. The Git history is the audit trail.

---

## Verified Results

| Capability | Status | Evidence |
|------------|--------|---------|
| staging-api-service sync | Synced — Healthy | Verified |
| production-api-service sync | Synced — Healthy | Verified |
| Drift correction | Under 2 seconds | Verified |
| AppProject RBAC | platform-admin + developer roles | Verified |
| ApplicationSet matrix generator | 2 environments from 1 template | Verified |
| Sync waves enforced | Wave 0 → 1 → 2 → 3 | Verified |
| OPA no-latest-tag constraint | Applied and active | Verified |
| Kyverno resource limits policy | Applied and active | Verified |
| Kyverno disallow-privileged | Applied and active | Verified |
| Canary rollout definition | Configured 10%→25%→50%→100% | Configuration verified |
| Canary runtime execution | Not fully verified — see Verification Matrix |
| Sloth SLO definition | Applied | Processing not fully verified |
| Litmus chaos experiment | Applied | Completion not fully verified |

[SCREENSHOT: docs/evidence/01-argocd-apps-synced.png]

---

## The GitOps Control Loop

```
Engineer pushes to Git
          │
          ▼
    GitHub Repository
    (single source of truth)
          │
          │  ArgoCD polls every 180s
          ▼
    ArgoCD Application Controller
    ├── renders manifests via Kustomize
    ├── compares rendered output vs cluster state
    └── if different → applies the diff
          │
          ▼
    Kubernetes Cluster
    ├── staging    → 1 replica
    └── production → 2 replicas
```

### What happens when someone changes the cluster manually

```
kubectl scale deployment api-service -n production --replicas=5
          │
          ▼
Cluster state: 5 replicas
Git state:     2 replicas
          │
          ▼
ArgoCD detects mismatch (continuous watch, selfHeal: true)
          │
          ▼
ArgoCD applies Git state to cluster
          │
          ▼
Cluster state: 2 replicas
Time elapsed:  under 2 seconds
```

This was tested live. The correction happened faster than running a second `kubectl get pods` command. The 5-replica state never persisted long enough to screenshot — which is the point.

[SCREENSHOT: docs/evidence/05-drift-detection.png]

---

## What Was Built

### ArgoCD provisioned via Terraform
ArgoCD v7.3.11 and Argo Rollouts installed as `helm_release` resources in Terraform.
This connects the Terraform project pattern to this project:
- Terraform defines the GitOps tool as code
- The GitOps tool manages all application state
- Full IaC + GitOps story from one codebase

### Two environments from one ApplicationSet
```yaml
generators:
  - matrix:
      generators:
        - list:
            elements:
              - environment: staging
              - environment: production
        - list:
            elements:
              - app: api-service
```
Generates staging-api-service and production-api-service automatically.
Adding a new environment requires one line in the list.

### Kustomize overlays
- `apps/staging/` — patches base to 1 replica, adds staging label
- `apps/production/` — inherits 2 replicas from base, adds production label
- Base manifest not referenced cross-directory (ArgoCD security restriction — see INCIDENTS.md)

### AppProject RBAC
- platform-admin: sync any app, manage clusters and repos
- developer: view all apps, sync staging only, cannot touch production

### Sync waves — deploy order enforced
- Wave 0: Namespace
- Wave 1: ConfigMap and Services
- Wave 2: Deployments
- Wave 3: Rollouts

### Security policies
- OPA Gatekeeper installed — `no-latest-tag` ConstraintTemplate and constraint applied
- Kyverno installed — `require-resource-limits` and `disallow-privileged` ClusterPolicies applied

### Argo Rollouts — canary definition
Rollout manifest configured for progressive traffic shifting:
`10% → 30s pause → 25% → 30s pause → 50% → 30s pause → 100%`

### SLO definition
Sloth `PrometheusServiceLevel` manifest applied defining 99.9% availability for api-service.

### Chaos experiment definition
Litmus `ChaosEngine` manifest applied defining pod-delete experiment for api-service.

---

## Verification Matrix

This table separates what was implemented from what was verified at runtime.
A skeptical reviewer should be able to see exactly what was proven and what was not.

| Capability | Implemented | Runtime Verified |
|------------|-------------|-----------------|
| ArgoCD installed and running | Yes | Yes |
| Git drift correction | Yes | Yes — under 2 seconds |
| staging environment synced | Yes | Yes |
| production environment synced | Yes | Yes |
| AppProject RBAC | Yes | Yes — roles visible in cluster |
| ApplicationSet matrix | Yes | Yes — 2 apps generated |
| Sync waves | Yes | Yes — annotations present and applied |
| Kustomize overlays | Yes | Yes — 1 replica staging, 2 production |
| OPA no-latest-tag | Yes | Yes — constraint active in cluster |
| Kyverno resource limits | Yes | Yes — policy active in cluster |
| Kyverno disallow-privileged | Yes | Yes — policy active in cluster |
| Canary rollout definition | Yes | Configuration verified |
| Canary runtime execution | Yes | **Not fully verified** — no new image pushed to trigger it |
| Sloth SLO definition | Yes | Resource applied — Sloth controller processing not confirmed |
| Litmus chaos experiment | Yes | Resource applied — experiment completion not confirmed |

---

## Repository Structure

```
gitops-argocd-platform/
├── terraform/
│   ├── main.tf                    — ArgoCD + Argo Rollouts helm_release
│   └── argocd-values.yaml         — RBAC, metrics, resource limits
├── apps/
│   ├── base/
│   │   ├── deployment.yaml        — base manifest, security context, probes
│   │   └── namespace.yaml         — sync-wave: "0"
│   ├── staging/
│   │   ├── deployment.yaml        — copy of base
│   │   └── kustomization.yaml     — patch: 1 replica, staging label
│   └── production/
│       ├── deployment.yaml        — copy of base
│       ├── kustomization.yaml     — production label
│       └── rollout.yaml           — canary steps definition
├── argocd/
│   ├── projects/
│   │   └── platform-project.yaml  — AppProject with RBAC
│   └── appsets/
│       └── platform-appset.yaml   — ApplicationSet matrix generator
├── security/
│   ├── opa/
│   │   └── no-latest-tag.yaml     — OPA constraint template and constraint
│   └── kyverno/
│       └── require-resources.yaml — resource limits + no-privileged policies
├── observability/
│   └── sloth/
│       └── api-service-slo.yaml   — 99.9% availability SLO
├── chaos/
│   └── litmus/
│       └── pod-kill-experiment.yaml — pod-delete ChaosEngine
└── .github/workflows/
    └── gitops.yml                 — CI: security, validate, drift check
```

---

## CI/CD Pipeline

```
push to main
    │
    └── Security Scan
    │       ├── TruffleHog    — secret scanning
    │       └── tfsec         — Terraform security scan
    │
    └── Validate Manifests
    │       └── kubectl dry-run on all YAML files
    │
    └── Validate Terraform
    │       ├── terraform fmt -check
    │       ├── terraform init -backend=false
    │       └── terraform validate
    │
    └── Drift Check
            ├── sync-wave annotations present
            ├── security contexts present
            ├── resource limits present
            ├── SLO definitions present
            └── chaos experiments present
```

[SCREENSHOT: docs/evidence/11-ci-pipeline-green.png]

---

## Quick Start

```bash
# Deploy ArgoCD via Terraform
cd terraform/
terraform init
terraform apply -auto-approve

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

# Port-forward and login
kubectl port-forward svc/argocd-server -n argocd 8080:80 &
argocd login localhost:8080 --username admin --insecure

# Apply GitOps resources
kubectl apply -f argocd/projects/platform-project.yaml
kubectl apply -f argocd/appsets/platform-appset.yaml

# Sync and verify
argocd app sync staging-api-service --insecure
argocd app sync production-api-service --insecure
argocd app list
```

---

## Documentation

| File | Contents |
|------|----------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | GitOps flow, component roles, sync waves, Kustomize |
| [GITOPS_MODEL.md](docs/GITOPS_MODEL.md) | How sync works, selfHeal, rollback, ApplicationSet |
| [SECURITY.md](docs/SECURITY.md) | AppProject restrictions, OPA, Kyverno |
| [ADR.md](docs/ADR.md) | Kustomize vs Helm, automated vs manual sync |
| [INCIDENTS.md](docs/INCIDENTS.md) | ComparisonError, drift too fast to screenshot |
| [GAPS.md](docs/GAPS.md) | Rollouts not triggered, Image Updater, multi-cluster |

---

## Related Projects

- [Auto-Healing Kubernetes Platform](https://github.com/velrite/auto-healing-k8s--) — the platform being managed
- [Terraform Kubernetes Platform](https://github.com/velrite/Terraform-Kubernetes-Platform) — same IaC pattern used to provision ArgoCD
