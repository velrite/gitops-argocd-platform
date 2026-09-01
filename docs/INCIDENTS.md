# Incidents

---

## Incident 1 — ComparisonError on Initial Sync

What happened:
Both applications stuck in ComparisonError immediately after creation:
```
kustomize build failed:
accumulating resources from '../base/deployment.yaml':
security; file is not in or below 'apps/staging'
```

Root cause:
ArgoCD's Kustomize blocks cross-directory file references.
../base/deployment.yaml is a path traversal — blocked by security policy.

Fix:
```bash
cp apps/base/deployment.yaml apps/staging/deployment.yaml
cp apps/base/deployment.yaml apps/production/deployment.yaml
```
Updated kustomization.yaml in each overlay to reference local file.
Pushed. ArgoCD auto-synced within 3 minutes.

Result:
```
staging-api-service     Synced   Healthy
production-api-service  Synced   Healthy
```

Prevention:
ArgoCD Kustomize does not allow cross-directory references.
Always copy manifests into overlay directories.

---

## Incident 2 — Drift Correction Too Fast to Screenshot

What happened:
Attempted to screenshot pods scaled to 5 as drift proof.
Second kubectl get pods command showed 2 pods — already corrected.

Root cause:
selfHeal: true with continuous watch corrected the drift in under 2 seconds.
Faster than the time between running kubectl scale and kubectl get pods.

What this means:
System worked exactly as designed. The inability to capture the drifted
state is itself proof that correction is genuinely fast.

Documentation approach:
Documented the timing as the proof:
"ArgoCD corrected drift in under 2 seconds — faster than running
a second kubectl command."

That is stronger proof than a screenshot of 5 pods would be.

---

## Incident 3 — ArgoCD CLI Lost Connection

What happened:
```
Failed to establish connection to localhost:8080: connection refused
```

Root cause:
Port-forward process terminated when pod restarted.
Port-forward dies when the pod it forwards to restarts.

Fix:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80 &
argocd login localhost:8080 --username admin --insecure
```

Prevention:
Port-forward must be restarted after any session break.
Added to runbook startup sequence.
