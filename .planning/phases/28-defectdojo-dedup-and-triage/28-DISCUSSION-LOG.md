# Phase 28: DefectDojo Dedup and Triage - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-25
**Phase:** 28-defectdojo-dedup-and-triage
**Areas discussed:** Dedup scope vs branches, Cross-tool ambition, Where config lives + proof, Triage record and scope

---

## Dedup scope vs branches

| Option | Description | Selected |
|--------|-------------|----------|
| Product-wide | DefectDojo default; PR findings already on main become duplicates, PR shows only new findings | ✓ |
| Per-engagement only | `deduplication_on_engagement=true`; each branch engagement stands alone | |
| You decide | Researcher picks | |

**User's choice:** Product-wide.

| Option | Description | Selected |
|--------|-------------|----------|
| Main copy must end active | Hard requirement after PR delete; cleanup job fixes if needed | |
| Next daily reimport fixes it | Accept up to 24h window; researcher verifies the heal is real | ✓ |
| You decide | Least-code option | |

**User's choice:** Next daily reimport fixes it (orphaned-duplicate edge case).

| Option | Description | Selected |
|--------|-------------|----------|
| Cleanup job re-parents | Extend defectdojo-cleanup before DELETE; security.yml change, v1.x tag | ✓ |
| Fall back to per-engagement | Lose PR noise reduction | |
| Document as known limitation | Operator fixes by hand | |

**User's choice:** Cleanup job re-parents (fallback if the reimport does not heal).

| Option | Description | Selected |
|--------|-------------|----------|
| Leave off | Upstream default; reimport-in-place already prevents pile-up | ✓ |
| Enable, low max | Bound DB growth | |
| You decide | | |

**User's choice:** Leave Delete Deduplicate Findings / Maximum Duplicates off.

---

## Cross-tool ambition

| Option | Description | Selected |
|--------|-------------|----------|
| SCA CVE overlap only | Trivy fs vs npm-audit vs pip-audit via custom hash fields | ✓ |
| Within-tool only, document gap | Upstream defaults | |
| All overlapping pairs | Also Checkov/tflint, Semgrep/Gitleaks | |

| Option | Description | Selected |
|--------|-------------|----------|
| Whichever imports first | Native behaviour; import table order makes it deterministic | ✓ |
| Ecosystem tool wins | Reorder imports; security.yml change | |
| You decide | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Document gap, ship within-tool | No normaliser; ADR records measured reason | ✓ |
| Stop and ask me | Blocker | |
| Drop one tool from import | Changes Phase 27 table | |

| Option | Description | Selected |
|--------|-------------|----------|
| Document recompute step | README note, no automation | ✓ |
| Automate via chart Job | Post-upgrade hook | |
| Ignore | | |

---

## Where config lives + proof

| Option | Description | Selected |
|--------|-------------|----------|
| Chart values.yaml defaults | DD_* env defaults, overridable, gated | ✓ |
| Documented overlay snippet | Chart stays thin | |
| You decide | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Idempotent bootstrap script | PATCH /api/v2/system_settings/; no security.yml change | ✓ |
| Chart post-install hook Job | Automatic, more chart surface | |
| Docs-only UI steps | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Extend kind proof now | Extend defectdojo-import-proof.sh with dedup/triage assertions | ✓ |
| Local kind only, no GH run | | |
| Defer to Phase 29 | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Both, via existing workflow | Local kind + real GH Actions run | ✓ |
| Local kind only | | |

---

## Triage record and scope

| Option | Description | Selected |
|--------|-------------|----------|
| DefectDojo authoritative | GitHub Security tab = per-PR feedback, no sync | ✓ |
| GitHub Security tab authoritative | | |
| Both, independently | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Default-branch engagement only | PR engagements transient | ✓ |
| Anywhere; warn about PR loss | | |

| Option | Description | Selected |
|--------|-------------|----------|
| Core set | Active, FP, Risk Accepted (expiry+reason), Out of Scope, Mitigated | |
| Minimal | Active, FP, Mitigated | |
| Core + Under Review | Core set plus explicit Under Review state | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| Enable, upstream defaults | SLA on via bootstrap | |
| Enable, custom days | | |
| Out of scope | Triage = dispositions only | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| security-platform docs + guide link | Runbook next to chart/script; adoption guide links | ✓ |
| This repo docs/ | | |
| Both | | |

---

## Claude's Discretion

- Bootstrap script name, runbook file path, proof assertion structure.
- Exact hash-field set per scanner (within D-05/D-07).
- Mapping of "Under Review" onto DefectDojo fields.
- Whether a security-platform tag is needed (only if security.yml or the callers change).

## Deferred Ideas

- SLA tracking (excluded).
- Automated hash recompute Job.
- Cross-tool dedup for IaC and secrets.
- Syncing dispositions to GitHub code scanning alerts.
- Multi-triager token/role model.
