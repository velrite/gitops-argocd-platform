# Security

## AppProject Restrictions

The platform AppProject enforces three boundaries:

**Source repository restriction:**
ArgoCD can only pull manifests from:
```
https://github.com/velrite/gitops-argocd-platform
```
Cannot be instructed to deploy from any other repository.

**Destination restriction:**
Applications can only deploy to:
- staging namespace on local cluster
- production namespace on local cluster

Cannot deploy to arbitrary namespaces or clusters.

**RBAC restriction:**
- platform-admin: full access to all applications
- developer: read all, sync staging only

---

## No Credentials in Git

No passwords, tokens, API keys, or secrets stored in any manifest file.
Kubernetes secrets referenced by name and created separately outside Git.

Vault integration planned but not implemented in this project.
See [GAPS.md](GAPS.md#external-secrets-not-configured).

---

## Security Context on All Containers

All application manifests include security context:
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000

containers:
  - securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
```

Kyverno policy enforces these on all production pods:
```yaml
kind: ClusterPolicy
metadata:
  name: disallow-privileged
spec:
  validationFailureAction: enforce
  rules:
    - name: check-privileged
      validate:
        pattern:
          spec:
            containers:
              - =(securityContext):
                  =(privileged): false
```

---

## OPA Gatekeeper — No Latest Tag

Production deployments with `:latest` image tag are blocked
at admission by OPA Gatekeeper constraint:

```rego
violation[{"msg": msg}] {
  container := input.review.object.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Container %v uses latest tag — not allowed", [container.name])
}
```

All images must use explicit version tags (e.g. `nginx:1.25-alpine`).

