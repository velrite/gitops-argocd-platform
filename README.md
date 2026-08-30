# GitOps ArgoCD Platform

> Git is the only source of truth. The cluster is a reflection of it.

**Author:** Olamide Olalekan — Platform & DevSecOps Engineer
**GitHub:** [github.com/velrite](https://github.com/velrite)
**LinkedIn:** [linkedin.com/in/olamide-olalekan-12138a265](https://linkedin.com/in/olamide-olalekan-12138a265)
**Email:** velrite.tech@gmail.com

**Connects to:**
- [Project 1 — Auto-Healing Kubernetes Platform](https://github.com/velrite/auto-healing-k8s--)
- [Project 2 — Terraform Kubernetes Platform](https://github.com/velrite/Terraform-Kubernetes-Platform)

---

## The Problem This Solves

In Projects 1 and 2, deployment still required human action:
- `kubectl apply` to deploy applications
- `helm install` to install tools
- Manual verification after each step

This project eliminates all of it.

Push to Git. ArgoCD syncs the cluster.
If someone changes the cluster manually, ArgoCD corrects it.
The Git history is the audit trail. Rollback is `git revert`.

No kubectl in production. Ever.

---

## Proven Results

### Drift Detection — Under 2 Seconds

```bash
kubectl scale deployment api-service -n production --replicas=5
# Manually set 5 replicas — this is drift from Git (which says 2)

kubectl get pods -n production
# Still showing 2 pods — ArgoCD corrected before second command returned
```

ArgoCD detected the drift and corrected it faster than a second
kubectl command could execute. The 5-replica state never persisted
long enough to be captured in a screenshot.

[SCREENSHOT: ArgoCD UI showing production-api-service Synced and Healthy]

### Multi-Environment from One Repo

```
staging-api-service    — Synced — Healthy — 1 replica
production-api-service — Synced — Healthy — 2 replicas
```

Both environments managed from a single ApplicationSet template.
[SCREENSHOT: argocd app list showing both apps Synced and Healthy]

---

## Architecture

```
GitHub Repository (single source of truth)
         │
         │ ArgoCD polls every 180 seconds
         │ (or immediately via webhook)
         ▼
    ┌─────────────────────────────────────┐
    │          ArgoCD (namespace: argocd) │
    │                                     │
    │  Application Controller             │
    │  ├── compares Git vs cluster state  │
    │  ├── detects drift                  │
    │  └── triggers sync                  │
    │                                     │
    │  ApplicationSet Controller          │
    │  └── generates Applications from   │
    │      matrix generator template      │
    └──────────────┬──────────────────────┘
                   │
         ┌─────────┴─────────┐
         ▼                   ▼
   staging namespace    production namespace
   1 replica            2 replicas
   auto-sync            auto-sync + selfHeal
```

---

## Repository Structure

```
gitops-argocd-platform/
├── terraform/                    — provisions ArgoCD via Helm
│   ├── main.tf                   — ArgoCD + Argo Rollouts helm_release
│   └── argocd-values.yaml        — RBAC, metrics, resource limits
├── apps/
│   ├── base/
│   │   └── deployment.yaml       — base manifest (nginx demo app)
│   ├── staging/
│   │   ├── deployment.yaml       — copy of base
│   │   └── kustomization.yaml    — patch: 1 replica, staging label
│   └── production/
│       ├── deployment.yaml       — copy of base
│       ├── kustomization.yaml    — patch: 2 replicas, production label
│       └── rollout.yaml          — Argo Rollouts canary definition
├── argocd/
│   ├── projects/
│   │   └── platform-project.yaml — RBAC: who can deploy where
│   └── appsets/
│       └── platform-appset.yaml  — ApplicationSet: staging + production
├── security/
│   ├── opa/                      — OPA Gatekeeper constraints
│   └── kyverno/                  — Kyverno policies
├── observability/
│   └── sloth/                    — SLO definitions
├── chaos/
│   └── litmus/                   — Chaos experiments
└── .github/workflows/
    └── gitops.yml               — CI: security scan, validate, drift check
```

---

## Key Concepts

### Why Git over ArgoCD UI?
Git provides audit trail, peer review via PRs, and rollback via `git revert`.
The UI is for visibility only. Every change goes through Git.
That is the definition of GitOps.

### selfHeal
`selfHeal: true` means ArgoCD watches the cluster continuously
and reverts any manual change immediately.
Tested result: drift corrected in under 2 seconds.

### ApplicationSet Matrix Generator
One template generates N applications from combinations of environments and apps.
Add a new environment by adding one line to the generator list.
No duplication. No manual Application creation.

### Sync Waves
Resources deploy in order via annotations:
- Wave 0: Namespace
- Wave 1: ConfigMap, Services
- Wave 2: Deployments
- Wave 3: Rollouts

Prevents deployment starting before its dependencies exist.

---

## Quick Start

### Prerequisites
- Minikube running with prod-sim profile
- kubectl, helm, ArgoCD CLI installed
- This repository pushed to GitHub

### Deploy ArgoCD via Terraform
```bash
cd terraform/
terraform init
terraform apply -auto-approve
```

### Connect ArgoCD to this repo
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80 &
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --username admin \
  --password $ARGOCD_PASS --insecure
```

### Apply GitOps resources
```bash
kubectl apply -f argocd/projects/platform-project.yaml
kubectl apply -f argocd/appsets/platform-appset.yaml
argocd app list
```

### Watch auto-sync
```bash
# ArgoCD will detect the repo and sync within 3 minutes
# Or trigger immediately:
argocd app sync staging-api-service --insecure
argocd app sync production-api-service --insecure
kubectl get pods -n staging
kubectl get pods -n production
```

---

## CI/CD Pipeline

```
push to main
  └── Security Scan
  │     ├── TruffleHog  — secret scanning
  │     └── tfsec       — Terraform security scan
  └── Validate Manifests
  │     └── kubectl dry-run on all YAML files
  └── Validate Terraform
  │     ├── terraform fmt -check
  │     ├── terraform init -backend=false
  │     └── terraform validate
  └── Drift Check
        ├── verify sync-wave annotations present
        ├── verify security contexts present
        ├── verify resource limits present
        └── verify SLO definitions exist
```

[SCREENSHOT: GitHub Actions showing all 4 stages green]

---

## RBAC

Two roles defined in AppProject:

| Role | Can Do | Cannot Do |
|------|--------|-----------|
| platform-admin | Sync any app, manage clusters and repos | — |
| developer | View all apps, sync staging only | Touch production directly |

Developers push to Git. ArgoCD handles production.

---

## Documentation

| Document | What It Covers |
|----------|---------------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Full GitOps flow, component design |
| [GITOPS_MODEL.md](docs/GITOPS_MODEL.md) | How sync works, selfHeal, rollback model |
| [SECURITY.md](docs/SECURITY.md) | RBAC, source repo restrictions, secrets |
| [ADR.md](docs/ADR.md) | Kustomize vs Helm, automated vs manual sync |
| [INCIDENTS.md](docs/INCIDENTS.md) | ComparisonError, drift correction timing |
| [GAPS.md](docs/GAPS.md) | Image updater, Rollouts trigger, multi-cluster |

---

## Author

Olamide Olalekan — Platform & DevSecOps Engineer
GitHub: [github.com/velrite](https://github.com/velrite)
LinkedIn: [linkedin.com/in/olamide-olalekan-12138a265](https://linkedin.com/in/olamide-olalekan-12138a265)
