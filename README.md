# GitOps ArgoCD Platform

Git is the only source of truth. The cluster is a reflection of it.

**Author:** Olamide Olalekan — Platform & DevSecOps Engineer
**GitHub:** [github.com/velrite](https://github.com/velrite)
**LinkedIn:** [linkedin.com/in/olamide-olalekan-12138a265](https://linkedin.com/in/olamide-olalekan-12138a265)
**Email:** velrite.tech@gmail.com

---

## What This Is

A GitOps platform where every deployment happens through Git.
Push to Git — ArgoCD syncs the cluster automatically.
Change the cluster manually — ArgoCD corrects it automatically.
Rollback is git revert — not kubectl commands.

---

## Proven

### Both environments synced and healthy
```
NAME                           SYNC STATUS   HEALTH STATUS
argocd/staging-api-service     Synced        Healthy
argocd/production-api-service  Synced        Healthy
```

[SCREENSHOT: argocd app list showing both Synced and Healthy]

### Drift corrected in under 2 seconds
```bash
kubectl scale deployment api-service -n production --replicas=5
kubectl get pods -n production
# Shows 2 pods — ArgoCD corrected before second command returned
```

The correction happened faster than running a second kubectl command.
That is selfHeal working as designed.

---

## What Was Built

### ArgoCD installed via Terraform
ArgoCD v7.3.11 and Argo Rollouts installed as Terraform helm_release resources.
Connects Project 2 pattern — the GitOps tool itself is defined as code.

### Kustomize overlays — two environments
- staging: 1 replica, environment=staging label
- production: 2 replicas, environment=production label
- Both managed from one ApplicationSet template

### AppProject — RBAC
- platform-admin role: sync any app, manage clusters and repos
- developer role: view all, sync staging only, cannot touch production

### ApplicationSet — matrix generator
One template generates staging-api-service and production-api-service.
Adding a new environment requires one line in the generator list.

### Sync waves — deploy order enforced
- Wave 0: Namespace
- Wave 1: ConfigMap and Services
- Wave 2: Deployments
- Wave 3: Rollouts

### Argo Rollouts — canary definition
Rollout manifest defined with canary steps:
10% → 30s pause → 25% → 30s pause → 50% → 30s pause → 100%

### Security policies applied
- OPA Gatekeeper installed — no-latest-tag constraint applied
- Kyverno installed — require-resource-limits and disallow-privileged policies applied

### SLO definition created
Sloth PrometheusServiceLevel manifest created and applied —
99.9% availability SLO for api-service.

### Chaos experiment defined
Litmus ChaosEngine manifest created and applied —
pod-delete experiment targeting api-service in production.

### CI/CD pipeline
4 jobs: Security Scan, Validate Manifests, Validate Terraform, Drift Check.
All confirmed green.

---

## Repository Structure

```
gitops-argocd-platform/
├── terraform/
│   ├── main.tf                    — ArgoCD + Argo Rollouts helm_release
│   └── argocd-values.yaml         — RBAC, metrics, resource limits
├── apps/
│   ├── base/
│   │   ├── deployment.yaml        — base manifest with security context
│   │   └── namespace.yaml         — sync-wave: "0"
│   ├── staging/
│   │   ├── deployment.yaml        — copy of base
│   │   └── kustomization.yaml     — patch: 1 replica, staging label
│   └── production/
│       ├── deployment.yaml        — copy of base
│       ├── kustomization.yaml     — patch: production label
│       └── rollout.yaml           — canary steps definition
├── argocd/
│   ├── projects/
│   │   └── platform-project.yaml  — RBAC roles
│   └── appsets/
│       └── platform-appset.yaml   — ApplicationSet matrix generator
├── security/
│   ├── opa/
│   │   └── no-latest-tag.yaml     — OPA constraint template + constraint
│   └── kyverno/
│       └── require-resources.yaml — resource limits + no privileged policy
├── observability/
│   └── sloth/
│       └── api-service-slo.yaml   — 99.9% availability SLO
├── chaos/
│   └── litmus/
│       └── pod-kill-experiment.yaml — pod-delete ChaosEngine
└── .github/workflows/
    └── gitops.yml                 — CI pipeline
```

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

# Sync
argocd app sync staging-api-service --insecure
argocd app sync production-api-service --insecure
argocd app list
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
        ├── sync-wave annotations present
        ├── security contexts present
        ├── resource limits present
        ├── SLO definitions present
        └── chaos experiments present
```

[SCREENSHOT: GitHub Actions showing all 4 stages green]

---

## Documentation

| File | Contents |
|------|----------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | GitOps flow, component roles, Kustomize design, sync waves |
| [GITOPS_MODEL.md](docs/GITOPS_MODEL.md) | How sync works, selfHeal, rollback model, ApplicationSet |
| [SECURITY.md](docs/SECURITY.md) | RBAC, AppProject restrictions, OPA, Kyverno |
| [ADR.md](docs/ADR.md) | Kustomize vs Helm, automated vs manual sync, selfHeal |
| [INCIDENTS.md](docs/INCIDENTS.md) | ComparisonError, drift too fast to screenshot |
| [GAPS.md](docs/GAPS.md) | Rollouts not triggered, Image Updater, External Secrets |

---

## Related Projects

- [Project 1 — Auto-Healing Kubernetes Platform](https://github.com/velrite/auto-healing-k8s--) — the platform being managed
- [Project 2 — Terraform Kubernetes Platform](https://github.com/velrite/Terraform-Kubernetes-Platform) — same IaC pattern used to provision ArgoCD
