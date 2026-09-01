# Gaps and Honest Limits

---

## Argo Rollouts Canary Not Triggered

Rollout manifest defined with canary steps.
Not triggered during testing because triggering requires pushing
a new image tag to a registry — the demo app is nginx from Docker Hub,
not a custom image this project owns.

What demonstrating it requires:
- Build a custom container image
- Push to ECR or Docker Hub
- Configure Image Updater to detect new tags
- New tag triggers Rollout and canary progression

---

## Image Updater Not Installed

ArgoCD Image Updater was not installed.
Updating an image currently requires manually editing the manifest
in Git and pushing.

What it would do:
Watch registry for new tags matching a pattern.
When new tag appears, commit the new tag to Git automatically.
ArgoCD then syncs the cluster.

---

## External Secrets Not Configured

Secrets are Kubernetes secrets created manually.
External Secrets Operator not installed.

Production would pull secrets from Vault or AWS Secrets Manager
via External Secrets Operator instead of creating them manually.

---

## Single Cluster Only

ApplicationSet targets local Minikube cluster only.
Multi-cluster GitOps would register multiple clusters with ArgoCD
and target Applications to appropriate clusters.

---

## Sloth SLO — No Prometheus Operator CRD

Sloth PrometheusServiceLevel manifest was created and applied.
Whether Sloth controller was running to process it and generate
the actual Prometheus recording rules was not verified.
Sloth requires its own controller to be installed separately.

---

## Litmus ChaosEngine — Not Verified Running

ChaosEngine manifest was created and applied.
Litmus was installed via helm.
Whether the actual chaos experiment ran and completed successfully
was not captured in terminal output.
