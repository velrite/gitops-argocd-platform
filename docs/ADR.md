# Architecture Decision Records

---

## ADR-001 — Kustomize over Helm for application manifests

Context: needed environment differences between staging and production.

Decision: Kustomize overlays.

Alternatives rejected:
- Helm — better for distributing reusable charts. For own application
  across two environments, Kustomize patches are simpler.
- Plain YAML per environment — copying creates drift between environments.

Trade-off: Kustomize requires copying base into each overlay because
ArgoCD blocks cross-directory references. Some duplication exists.
Acceptable for two environments.

---

## ADR-002 — ApplicationSet over individual Application manifests

Context: two environments both running api-service.

Decision: single ApplicationSet with matrix generator.

Alternatives rejected:
- Two separate Application manifests — N environments × M apps = N×M files.
  Does not scale.

Trade-off: ApplicationSet adds abstraction. Debugging requires understanding
generator output. Worth it for any platform with more than one environment.

---

## ADR-003 — automated sync with selfHeal

Context: sync policy for both environments.

Decision: automated sync with selfHeal: true on both.

Alternatives rejected:
- Manual sync for production — requires human action on every merge.
  Defeats GitOps automation purpose.
- Automated without selfHeal — would not correct manual cluster changes.
  Half the GitOps value would be missing.

Trade-off: selfHeal removes ability to hotfix cluster directly.
All changes must go through Git. Intentional — enforces proper change management.

---

## ADR-004 — Copy base manifests into overlays

Context: overlays need base deployment manifest.

Decision: copy deployment.yaml into each overlay directory.

Alternatives rejected:
- Reference ../base/deployment.yaml — natural Kustomize pattern but blocked
  by ArgoCD security restrictions. Produces ComparisonError on first sync.
  See INCIDENTS.md.

Trade-off: base manifest exists in three places. Change to base requires
updating three files. Acceptable for two environments.
