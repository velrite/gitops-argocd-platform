# Gaps and Honest Limits

---

## Image dater Not Configured

**What is missing:**
ArgoCD Image Updater was not installed.
Without it, updating an image requires manually editing the manifest
in Git and pushing.

**What Image Updater would do:**
Watch the container registry for new image tags matching a pattern.
When a new tag appears, automatically commit the new tag to Git.
ArgoCD then syncs the cluster to the new image.
Full automation from CI image push to cluster deployment.

**What building it requires:**
- ArgoCD Image Updater installed incd namespace
- Write access to Git repository via deploy key
- Image registry credentials stored as Kubernetes secret
- Annotation on each Application specifying which registry and tag pattern to watch

---

## Argo Rollouts Not Triggered in Testing

**What was built:**
Argo Rollouts installed. Rollout resource defined with canary strategy:
- 10% → 30s pause → 25% → 30s pause → 50% → 30s pause → 100%

**What is missing:**
The canary rollout was never triggered during testing.
Triggering requirespushing a new image tag, which requires
a container registry and a real image build.

The demo app (nginx:1.25-alpine) is a pre-built image from Docker Hub.
Pushing a new version of it is not something this project owns.

**What demonstrating it requires:**
- Build a simple custom container image (e.g. a Go HTTP server)
- Push to ECR or Docker Hub
- Configure Image Updater to detect new tags
- Update would trigger Rollout and canary progression would be visible

---

## External Secrets Not Configured

**What is missing:**
Secrets are Kubernetes secrets created manually.
External Secrets Operator was not installed.

**What production would use:**
External Secrets Operator pulling from Vault or AWS Secrets Manager:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-service-db-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: secret/api-service/db
        property: password
```

---

## Single Cluster Only

**What is missing:**
ApplicationSet targets the local Minikube cluster only.
A real multi-cluster GitOps setup would:
- Register multiple clusters with ArgoCD
- Target each Application to the appropriate cluster
- Show unified sync status across all clusters in one UI

**What multi-cluster requires:**
```bash
argocd cluster add production-eks-context
argocd cluster add staging-gke-context
```
Then update ApplicationSet destination to reference cluster by URL
rather than `https://kubernetes.default.svc`.

---

## Monitoring Not Integrated with ArgoCD

**What is missing:**
ArgoCD metrics are exposed (metrics.enabled: true in Helm values)
but not scraped by Prometheus or displayed in Grafana.

A production setup would have:
- Prometheus ServiceMonitor for ArgoCD metrics
- Grafana dashboard showing sync status, app health, sync duration
- Alerts when apps go OutOfSync for more than 5 minutes

