# Phase 28: DefectDojo Dedup and Triage - Context

**Gathered:** 2026-09-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Configure DefectDojo so that repeated findings collapse instead of duplicating (DDOJO-03), and define, configure and document a triage workflow for reviewing and dispositioning findings (DDOJO-04). The work lands in `OttawaCloudConsulting/security-platform`: new defaults in the Phase 26 wrapper chart, a new idempotent bootstrap script for database-level settings, an extended kind proof, and a triage runbook. This repository gets ADR-026 and an adoption-guide link.

Everything stays generic. Defaults ship in the public chart and script. Environment values stay in the consumer's private overlay.

NOT in this phase:
- Deploying to the homelab and choosing how runners reach DefectDojo (Phase 29, DDOJO-05). Phase 29 re-proves the behaviour from this phase live.
- SLA configuration (days-to-fix per severity). The operator ruled it out of scope.
- New integrations: Jira, notifications, writing dispositions back to GitHub code scanning alerts, adding Grype/Syft imports.
- Changing the Phase 27 import table or the import order, except where D-03's fallback requires a cleanup-job change.

</domain>

<decisions>
## Implementation Decisions

### Dedup scope across branch engagements
- **D-01:** Dedup is **product-wide**, which is the DefectDojo default. Do **not** set `deduplication_on_engagement=true`. A finding on a PR branch engagement (`ci/<branch>`) that already exists on the default-branch engagement becomes a duplicate of the default-branch finding. The PR engagement's active findings are then only the findings the PR introduces.
- **D-02:** Edge case: a finding first appears on a PR branch, and the PR merges. The default branch's copy then becomes a duplicate of the PR's original. When 27 D-10 deletes the PR engagement, the default-branch copy can be left as an orphaned duplicate. The operator accepts that **the next daily scheduled reimport heals this**, with a window of up to 24h. The researcher must **verify** against DefectDojo 3.3.200 that deletion or reimport actually re-parents or reactivates the orphan. Record how it behaves. Do not assume.
- **D-03:** **Fallback if D-02 is not true:** extend the `defectdojo-cleanup` job in `security.yml`. Before the DELETE, it resets or re-parents findings in other engagements whose duplicate original sits in the PR engagement. The 27 D-10 safety constraints still apply: exact-name match only, never the default branch, never a wildcard. This is a `security.yml` change, so it needs the GitHub proof run and a v1.x tag with a `v1` move (ADR-018, 27 D-16).
- **D-04:** Leave **"Delete Deduplicate Findings" / "Maximum Duplicates" off** (the upstream default). Reimport-in-place already stops a new Test per run (27 D-07). Branch overlap is the only source of duplicates, and closed PRs delete their engagements.

### Cross-tool dedup
- **D-05:** Cross-tool collapse targets the **SCA CVE overlap only**. When Trivy fs, NPM Audit v7+ and pip-audit report the same vulnerability in the same package, they collapse. The mechanism is custom hash-code fields per scanner, for example `vulnerability_ids` + `component_name` + `component_version`. The researcher picks the exact field set, and it must be checked against the 3.3.200 parsers' populated fields. IaC (Checkov/tflint) and secrets (Semgrep/Gitleaks) stay within-tool. The ADR states why.
- **D-06:** The **original is whichever finding imports first**. This is native DefectDojo behaviour. In practice the fixed import table (Trivy fs before npm/pip-audit) makes it deterministic. Do not change the import order.
- **D-07:** **Fallback if 3.3.200 cannot collapse the SCA overlap** (for example, `component_name` formats differ between parsers and no field combination matches): do not write a normaliser. Ship within-tool plus product-wide dedup, and record the measured reason in ADR-026. DDOJO-03 closes on that basis.
- **D-08:** Changing hash fields changes `hash_code` for findings that are already imported. The chart README **documents the recompute step**: the upstream dedupe management command, to run after changing hash settings on an existing install. Do not automate it. No live install exists yet; the homelab install is Phase 29.

### Where configuration lives
- **D-09:** Django-level dedup settings (hash fields per scanner, dedup algorithm per parser) ship as **defaults in `kubernetes/defectdojo/values.yaml`**. They are set through the upstream chart's env/extraConfigs mechanism (the researcher confirms the exact key) and consumers can override them. This deliberately widens 26 D-04 ("thin values") because the settings are DDOJO-03's substance. `scripts/check-defectdojo-chart.sh` is extended deliberately to assert the new defaults.
- **D-10:** Database-level System Settings go into a **new idempotent bootstrap script** in `security-platform` (name is Claude's discretion, for example `scripts/defectdojo-configure.sh`). This covers the enable-deduplication flag and the settings the triage workflow needs, such as risk acceptance enabled with expiry. The script PATCHes `/api/v2/system_settings/` with an admin-scoped token. The operator runs it once per install, and rerunning it changes nothing. The token handling follows the Phase 27 idiom: a 0600 header file, never on argv, https-only and TLS verified (ADR-025). The script does not change `security.yml`.

### Proof
- **D-11:** Extend the **kind proof now**: `scripts/defectdojo-import-proof.sh`, on top of the Phase 26 chart with the new values and the bootstrap script. The API assertions cover:
  - PR-branch findings that exist on the default branch are marked duplicates, and the PR engagement's active findings are only the new ones;
  - SCA cross-tool collapse works, or the measured gap per D-07;
  - False Positive, Risk Accepted and Out of Scope dispositions on the default-branch engagement **survive a reimport** and are not reactivated;
  - the D-02 orphan case after a PR engagement delete is healed by the next default-branch reimport, or the D-03 fallback is proven;
  - the bootstrap script is idempotent: a second run produces no change.
- **D-12:** The proof runs **both locally on kind and as a real GitHub Actions run**, through the existing path-filtered proof workflow. This is the same evidence standard as 27 D-19.

### Triage workflow
- **D-13:** **DefectDojo is the authoritative system of record** for triage. The GitHub Security tab (SARIF, CICD-02) is per-PR developer feedback and is not triaged. The two are not synced, and the runbook says so.
- **D-14:** Triage happens on the **default-branch engagement (`ci/<default>`) only**. PR engagements are transient review views and are deleted on close. The researcher verifies that, with product-wide dedup, a disposition on the default-branch original also suppresses its PR-branch duplicates.
- **D-15:** The workflow defines these dispositions:
  - **Under Review**: an explicit state for new findings awaiting triage;
  - **Verified/Active**;
  - **False Positive**;
  - **Risk Accepted**, with a mandatory expiry date and reason;
  - **Out of Scope**;
  - **Mitigated**: closed automatically by reimport through `close_old_findings`.

  **Hard requirement:** False Positive, Risk Accepted and Out of Scope must survive the daily reimport and must not be reactivated. The researcher confirms the 3.3.200 reimport semantics and any flag needed, for example `do_not_reactivate`. If a flag has to be added to the reimport call, that is a `security.yml` change and follows the v1.x path in D-03. The researcher also decides how "Under Review" maps onto DefectDojo's native fields.
- **D-16:** **SLA configuration is out of scope.** Triage means dispositions only. Do not enable SLA tracking or notifications.
- **D-17:** The triage runbook lives **in `security-platform`**, next to the chart and script it configures (the exact path is Claude's discretion, for example `kubernetes/defectdojo/TRIAGE.md`). `docs/adoption-guide.md` in this repository links to it, and `bash scripts/check-adoption-guide.sh` must stay green.

### Records (required, not discretionary)
- **D-18:** Write **ADR-026** (dedup scope, the cross-tool decision and its measured outcome, config homes, triage system of record, dispositions, and SLA excluded) and add its row to `docs/adr/README.md`. ADRs are append-only, so do not edit ADR-023/024/025.
- **D-19:** In `kubernetes/defectdojo/README.md`, change the rows for DDOJO-03 and DDOJO-04 (currently "Planned (Phase 28)", lines 52-53) to their delivered status. Mark DDOJO-03/04 Complete in `.planning/REQUIREMENTS.md`.

### Post-research operator decisions (2026-09-25, after 28-RESEARCH.md)
Research resolved D-02 (the engagement DELETE re-parents duplicates at once, so the D-03 fallback is not needed), D-05 (measured: no hash-field set collapses the SCA overlap in 3.3.200, so D-07 applies) and D-15 (FP, Out of Scope and Risk Accepted are never reactivated by reimport, so no reimport flag and no `security.yml` change). The operator then decided:
- **D-20:** Chart defaults in `kubernetes/defectdojo/values.yaml` (narrowing D-09): ship exactly two guards through `defectdojo.extraConfigs`. They are `DD_DUPLICATE_CLUSTER_CASCADE_DELETE: "False"` and `DD_DEDUPLICATION_ALGORITHM_PER_PARSER`, which restates the 3.3.200 algorithm for the 7 imported scan types as drift defence. Do **not** ship `DD_HASHCODE_FIELDS_PER_SCANNER` overrides. `scripts/check-defectdojo-chart.sh` asserts both.
- **D-21:** SLA: the bootstrap script does **not** touch `enable_finding_sla`. It stays at the upstream default. The runbook states that SLA is not part of triage and is not configured (D-16).
- **D-22:** Risk acceptance expiry: the bootstrap script sets `risk_acceptance_form_default_days` to **90**. DefectDojo cannot enforce the expiry or the reason, so the runbook makes both mandatory by procedure.
- **D-23:** "Under Review" is the **implicit untriaged queue**: active, not verified, no disposition, not a duplicate. The runbook gives the filter. Do not use the native `under_review` flag.
- **D-24:** Runbook link (D-17): `docs/adoption-guide.md` section 12 links the runbook with a `github.com/OttawaCloudConsulting/security-platform/blob/main/...` URL. The `/v1/` raw pin rule does not apply, because this phase moves no tag and the runbook is read by people, not fetched by code. `check-adoption-guide.sh` gains the runbook needle in `DD_REQUIRED`.

### Claude's Discretion
- The bootstrap script name, the runbook file name and location inside `security-platform`, and the exact assertion structure in the proof script.
- The exact hash-field set per scanner, within the limits of D-05 and D-07.
- How "Under Review" maps onto DefectDojo fields (D-15).
- Whether the release needs a new security-platform tag. A tag is required only if `security.yml` or the callers change; a chart-only or script-only change follows the chart's own versioning.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirement and project constraints
- `.planning/REQUIREMENTS.md`: DDOJO-03 and DDOJO-04 text; the Out of Scope table.
- `.planning/PROJECT.md`: the v3.0 goal and the generic-first Key Decision.
- `.planning/ROADMAP.md`: the Phase 28 goal and the Phase 29 boundary. Phase 29 proves 28 live.

### Prior phase context
- `.planning/phases/27-defectdojo-ci-auto-import/27-CONTEXT.md`: D-07 (reimport per branch engagement), D-10 (delete-on-close safety constraints), D-16 (v1 additive tagging), D-18/D-19/D-20 (TLS and proof harness).
- `.planning/phases/26-defectdojo-generic-chart/26-CONTEXT.md`: D-03 (3.3.200 pin), D-04 (thin values, widened by D-09 here), D-13 (existingSecret).
- `.planning/phases/26-defectdojo-generic-chart/26-REVIEW.md`: open warnings to keep in mind when reusing the harness.

### Code in security-platform (local clone `repos/security-platform/`)
- `repos/security-platform/.github/workflows/security.yml`: the `defectdojo-import` job (fixed import TABLE, the reimport-scan form fields, `close_old_findings=true`) and the `defectdojo-cleanup` job (the D-03 fallback target).
- `repos/security-platform/kubernetes/defectdojo/values.yaml`, `README.md` (lines 52-53, the DDOJO-03/04 rows), `Chart.yaml`: where the D-09 defaults and the D-08 recompute note go.
- `repos/security-platform/scripts/check-defectdojo-chart.sh`: the offline chart gate, extended for D-09.
- `repos/security-platform/scripts/defectdojo-import-proof.sh` and its proof workflow: extended for D-11/D-12.
- `repos/security-platform/scripts/defectdojo-live-smoke.sh`: the kind + chart bring-up.

### ADRs
- `docs/adr/adr023-defectdojo-chart-base-tls-guard-and-version-pin.md`: the 1.9.53 / 3.3.200 pin.
- `docs/adr/adr024-defectdojo-ci-import-reimport-per-branch-and-opt-in.md`: the import model this phase tunes.
- `docs/adr/adr025-defectdojo-import-https-only.md`: https-only, followed by the D-10 script.
- `docs/adr/adr018-workflow-packaging-canonical-host-and-versioning.md`: the v1.x rules if `security.yml` changes.
- `docs/adr/adr001-remove-continue-on-error.md`: the side-channel carve-out, if the cleanup job changes.
- `docs/adr/README.md`: the ADR index (the ADR-026 row goes here).

### Docs
- `docs/adoption-guide.md` and `scripts/check-adoption-guide.sh`: the triage runbook link (D-17).

### Upstream (verify against app 3.3.200, not latest docs)
- DefectDojo deduplication docs: hash_code vs unique_id_from_tool algorithms, `HASHCODE_FIELDS_PER_SCANNER` / `DEDUPLICATION_ALGORITHM_PER_PARSER` settings and their env overrides, `deduplication_on_engagement`, Delete Deduplicate Findings / Max Dupes, and the dedupe recompute management command.
- The DefectDojo `reimport-scan` fields affecting disposition survival (`do_not_reactivate`, `close_old_findings`) and how the engagement DELETE treats duplicate clusters.
- `/api/v2/system_settings/` fields (enable_deduplication, risk acceptance, related toggles).
- The upstream Helm chart env/extraConfigs mechanism for Django settings (chart 1.9.53).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The `defectdojo-import` job's python3 client idiom in `security.yml`: token in a 0600 header file, `--form-string` for non-file fields, https pin, CA bundle support. Reuse it for the bootstrap script's API calls.
- `scripts/defectdojo-import-proof.sh`: already mints a token, runs the committed import/cleanup bodies against kind DefectDojo, and asserts through the API. Extend it rather than build a new harness.
- `scripts/check-defectdojo-chart.sh`: the offline defaults-assertion gate pattern.

### Established Patterns
- Wrap upstream and override through values. Every default carries a WHY-comment.
- Side-channel jobs use `continue-on-error` plus a red verify step and are never required checks.
- Every setting and field name is verified against the pinned app version and measured live, never taken from latest docs.
- Scripts run as `bash script.sh`. Never set the executable bit.

### Integration Points
- Chart values → DefectDojo Django settings (dedup hash fields).
- Bootstrap script → `/api/v2/system_settings/` (dedup enable, risk acceptance).
- The proof workflow in `security-platform` → the GitHub Actions run (D-12).
- `docs/adoption-guide.md` → the runbook link.

</code_context>

<specifics>
## Specific Ideas

- The operator accepted up to 24h of orphaned-duplicate state after a PR delete (D-02), but only if the heal is real. The proof must show it.
- Dispositions surviving the daily reimport is the core triage guarantee (D-15). Assert it explicitly, not only by HTTP status.
- The operator explicitly chose "Under Review" as a named state in addition to the core dispositions.

</specifics>

<deferred>
## Deferred Ideas

- SLA tracking and days-to-fix per severity: excluded by the operator (D-16). Revisit if a reporting need appears.
- Automating the hash recompute through a chart hook Job (D-08 chose documentation only).
- Cross-tool dedup for IaC (Checkov/tflint) and secrets (Semgrep/Gitleaks): not attempted (D-05).
- Syncing DefectDojo dispositions to GitHub code scanning alerts: a new capability.
- A token and role model for multiple triagers (DefectDojo groups and permissions): not discussed; single-operator practice.

</deferred>

---

*Phase: 28-defectdojo-dedup-and-triage*
*Context gathered: 2026-09-25*
