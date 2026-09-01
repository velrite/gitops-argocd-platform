# Security

## AppProject Restrictions

Source repository: ArgoCD can only pull from this repo.
Cannot be instructed to deploy from any other source.

Destinations: only staging and production namespaces on local cluster.
Cannot deploy to arbitrary namespaces or clusters.

RBAC:
- platform-admin: sync any app, manage clusters and repos
- developer: view all, sync staging only

## OPA Gatekeeper — No Latest Tag

OPA Gatekeeper installed.
Constraint applied blocking :latest image tag in production:

```rego
violation[{"msg": msg}] {
  container := input.review.object.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Container %v uses latest tag", [container.name])
}
```

All images must use explicit version tags.

## Kyverno Policies

Kyverno installed.
Two policies applied:

require-resource-limits: enforces CPU and memory limits on all
production pods. Pod rejected at admission if limits missing.

disallow-privileged: blocks privileged containers in production.

## Security Context on All Manifests

All app manifests include:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
containers:
  - securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```

## No Credentials in Git

No passwords or tokens in any manifest file.
Kubernetes secrets created separately and not committed.
