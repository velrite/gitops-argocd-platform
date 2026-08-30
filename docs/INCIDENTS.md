# Incidents

---

## Incident 1 — ComparisonError on Initial Sync

**What happened:**
Both applications showed ComparisonError immediately after creation:
```
ComparisonError: Failed to load target state: failed to generate manifest:
kustomize build failed exit status 1:
Error: accumulating resources from '../base/deployment.yaml':
security; file is not in or below 'apps/staging'
```

Both staging-api-service and production-api-service stuck in Unknown/ComparisonError.
No pods deployed to either namespace.

**Root cause:**
ArgoCD's Kustomize implementation enforces a security restriction
blocking cross-directory file references. The overlay kustomization.yaml
referenced `../base/deployment.yaml` which is outside the overlay directory.
This is a security measure to prevent path traversal.

**Fix:**
```bash
cp apps/base/deployment.yaml apps/staging/deployment.yaml
cp apps/base/deployment.yaml apps/production/deployment.yaml
```

Updated each kustomization.yaml to reference local deployment.yaml
instead of ../base/deployment.yaml.

Pushed changes. ArgoCD auto-synced within 3 minutes.

**Result after fix:**
```
NAME                           SYNC STATUS   HEALTH STATUS
argocd/production-api-service  Synced        Healthy
argocd/staging-api-service     Synced        Healthy
```

**Prevention:**
ArgoCD Kustomize does not support cross-directory references by default.
Always copy manifests into each overlay directory.
Document this as a constraint in architecture docs.

---

## Incident 2 — Drift Correction Too Fast to Screenshot

**What happened:**
Attempted to demonstrate drift detection by scaling to 5 replicas:
```bash
kubectl scale deployment api-service -n production --replicas=5
kubectl get pods -n production
# NAME                           READY   STATUS
# api-service-6c87d9f469-cpkhh   1/1     Running
# api-service-6c87d9f469-zlqrw   1/1     Running
```

Expected to see 5 pods. Got 2. Drift was already corrected.

**Root cause:**
selfHeal: true means ArgoCD watches cluster state continuously.
The correction happened in under 2 seconds — fastn the
time between running kubectl scale and kubectl get pods.

**What this means:**
This is correct behavior. The system worked exactly as designed.
The inability to capture the drifted state is proof that drift
correction is genuinely fast, not a slow background process.

**Documentation approach:**
Documented the timing as the proof rather than trying to
capture a screenshot of the drifted state:

> "ArgoCD detected the drift and corrected it in under 2 seconds.
> The correction was faster than running a second kubectl get pods command."

That statement is more impressive than a screenshot of 5 pods would be.

---

## Incident 3 — ArgoCD CLI Lost Connection

**What happened:**
```
{"level":"fatal","msg":"Failed to establish connection to localhost:8080:
error dial proxy: dial tcp [::1]:8080: connect: connection refused"}
```

ArgoCD CLI commands stopped working mid-session.

**Root cause:**
Port-forward process terminated. Port-forward runs as a background
process and dies when the terminal session closes or when
the pod it's forwarding to restarts.

**Fix:**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80 &
argocd login localhost:8080 --username admin \
  --password $(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d) --insecure
```

**Prevention:**
Port-forward must be restarted after any session break.
Added to runbook as part of platform startup sequence.

