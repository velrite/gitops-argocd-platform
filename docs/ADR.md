# Architecture Decision Records

---

## ADR-001 — Kustomize over Helm for application manifests

**Context:**
Needed to manage environment differences between staging and production.

**Decision:** Kustomize overlays per environment.

**Alternatives rejected:**
- Helm — better for packaging reusable charts for distribution.
  For managing your own application across environments,
  Kustomize patches are simpler with less indirection.
  No need for template syntax ({{ .Values.replicas }}) for simple overrides.
- Plain YAML per environment — copying creates drift.
  Bug fix in base must be manually applied to all environments.

**Trade-off accepted:**
Kustomize requires copying the base manifest into each overlay
directory due to ArgoCD security restrictions on cross-directory
references. Some duplication exists for two environments.
For 5+ environments this trade-off reverses and Helm becomes preferable.

---

## ADR-002 — ApplicationSet over individual Application manifests

**Context:**
Two environments (staging, production) both running api-service.

**Decision:** Single ApplicationSet with matrix generator.

**Alternatives rejected:**
- Two separate Application manifests — works but scales poorly.
  Adding a third environment requires creating a third manifest.
  Adding a second app requires duplicating two manifests.
  N environments × M apps = N×M files to maintain.

**Trade-off accepted:**
ApplicationSet adds abstraction. Debugging requires understanding
generator output. Worth it for any platform with more than one
environment.

---

## ADR-003 — automated sync with selfHeal over manual sync for production

**Context:**
Needed to decide whether production auto-syncs or requires human approval.

**Decision:** Automated sync with selfHeal on both environments.

**Alternatives rejected:**
- Manual sync for production — common pattern for regulated environments.
  Requires engineer to click sync after every merge to main.
  Defeats the purpose of GitOps automation for this demonstration.
- Automated without selfHeal — would not correct manual cluster changes.
  Half of the GitOps value (drift correction) would be missing.

**Trade-off accepted:**
selfHeal removes the ability to make temporary hotfixes directly to
the cluster. All changes must go through Git and be committed.
This is intentional — it forces proper change management.

**What production at scale would consider:**
Manual sync gate for production with automated sync for staging.
Allows staging to move fast while production requires explicit approval.

---

## ADR-004 — Copy base manifests into overlays over cross-directory references

**Context:**
Kustomize overlays need access to base deployment manifest.

**Decision:** Copy deployment.yaml into each overlay directory.

**Alternatives rejected:**
- Reference ../base/deployment.yaml from overlay — natural Kustomize pattern.
  Blocked by ArgoCD security restrictions. ArgoCD does not allow
  Kustomize to reference files outside the application's source path.
  Attempts produce ComparisonError — see [INCIDENTS.md](INCIDENTS.md).

**Trade-off accepted:**
Some duplication — base manifest exists in base/, staging/, production/.
A change to base requires updating three files.
Acceptable for two environments. A real solution at scale would use
Helm or a monorepo structure that avoids the cross-directory limitation.

