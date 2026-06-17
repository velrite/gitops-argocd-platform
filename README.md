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
│   ├── staging/
│   └── production/
├── argocd/
│   ├── install/
│   ├── applications/
│   └── appsets/
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

| Environment | Sync Policy | Delivery Strategy |
|-------------|-------------|------------------|
| Staging | Automatic | Direct deployment |
| Production | Manual gate | Canary → Full |

---

## Deployment Workflow

1. Developer updates application manifest or image tag
2. Pull Request opened for peer review
3. Merge to main triggers ArgoCD sync detection
4. Cluster synchronizes automatically to declared state
5. Argo Rollouts begins canary deployment in production
6. Prometheus validates SLO thresholds continuously
7. Full promotion on success — automatic rollback on breach

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
- No manual promotion decisions required

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
| Manual cluster modification | ArgoCD detects and auto-reconciles |
| Failed image deployment | Rollout halted — no traffic impact |
| Canary SLO breach | Automatic rollback triggered |
| Application sync failure | Prometheus alert generated |
| Secret expiration | Vault re-issues credential automatically |

---

## Technical Decisions

**Why ArgoCD over Flux**
ArgoCD provides a richer application model with ApplicationSets
for multi-environment management and immediate visibility into
drift state across all applications simultaneously.

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
- Progressive delivery requires observability to be useful —
  metric-driven promotion only works if the metrics are meaningful
- Secret management must be designed before the first deployment
  not retrofitted after
- ApplicationSets significantly reduce the operational overhead
  of managing multiple environments

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
