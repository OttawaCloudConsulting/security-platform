# Phase 28: DefectDojo Dedup and Triage - Research

**Researched:** 2026-09-25
**Domain:** DefectDojo 3.3.200 deduplication engine, reimport semantics, System Settings API, upstream Helm chart 1.9.53 env injection, triage dispositions
**Confidence:** HIGH for engine behaviour (read in the pinned 3.3.200 source), HIGH for the cross-tool gap (measured locally with the same scanner flags security.yml uses), MEDIUM for the proof design (not yet run)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Dedup scope across branch engagements
- **D-01:** Dedup is **product-wide**, which is the DefectDojo default. Do **not** set `deduplication_on_engagement=true`. A finding on a PR branch engagement (`ci/<branch>`) that already exists on the default-branch engagement becomes a duplicate of the default-branch finding. The PR engagement's active findings are then only the findings the PR introduces.
- **D-02:** Edge case: a finding first appears on a PR branch, and the PR merges. The default branch's copy then becomes a duplicate of the PR's original. When 27 D-10 deletes the PR engagement, the default-branch copy can be left as an orphaned duplicate. The operator accepts that **the next daily scheduled reimport heals this**, with a window of up to 24h. The researcher must **verify** against DefectDojo 3.3.200 that deletion or reimport actually re-parents or reactivates the orphan. Record how it behaves. Do not assume.
- **D-03:** **Fallback if D-02 is not true:** extend the `defectdojo-cleanup` job in `security.yml`. Before the DELETE, it resets or re-parents findings in other engagements whose duplicate original sits in the PR engagement. The 27 D-10 safety constraints still apply: exact-name match only, never the default branch, never a wildcard. This is a `security.yml` change, so it needs the GitHub proof run and a v1.x tag with a `v1` move (ADR-018, 27 D-16).
- **D-04:** Leave **"Delete Deduplicate Findings" / "Maximum Duplicates" off** (the upstream default). Reimport-in-place already stops a new Test per run (27 D-07). Branch overlap is the only source of duplicates, and closed PRs delete their engagements.

#### Cross-tool dedup
- **D-05:** Cross-tool collapse targets the **SCA CVE overlap only**. When Trivy fs, NPM Audit v7+ and pip-audit report the same vulnerability in the same package, they collapse. The mechanism is custom hash-code fields per scanner, for example `vulnerability_ids` + `component_name` + `component_version`. The researcher picks the exact field set, and it must be checked against the 3.3.200 parsers' populated fields. IaC (Checkov/tflint) and secrets (Semgrep/Gitleaks) stay within-tool. The ADR states why.
- **D-06:** The **original is whichever finding imports first**. This is native DefectDojo behaviour. In practice the fixed import table (Trivy fs before npm/pip-audit) makes it deterministic. Do not change the import order.
- **D-07:** **Fallback if 3.3.200 cannot collapse the SCA overlap** (for example, `component_name` formats differ between parsers and no field combination matches): do not write a normaliser. Ship within-tool plus product-wide dedup, and record the measured reason in ADR-026. DDOJO-03 closes on that basis.
- **D-08:** Changing hash fields changes `hash_code` for findings that are already imported. The chart README **documents the recompute step**: the upstream dedupe management command, to run after changing hash settings on an existing install. Do not automate it. No live install exists yet; the homelab install is Phase 29.

#### Where configuration lives
- **D-09:** Django-level dedup settings (hash fields per scanner, dedup algorithm per parser) ship as **defaults in `kubernetes/defectdojo/values.yaml`**. They are set through the upstream chart's env/extraConfigs mechanism (the researcher confirms the exact key) and consumers can override them. This deliberately widens 26 D-04 ("thin values") because the settings are DDOJO-03's substance. `scripts/check-defectdojo-chart.sh` is extended deliberately to assert the new defaults.
- **D-10:** Database-level System Settings go into a **new idempotent bootstrap script** in `security-platform` (name is Claude's discretion, for example `scripts/defectdojo-configure.sh`). This covers the enable-deduplication flag and the settings the triage workflow needs, such as risk acceptance enabled with expiry. The script PATCHes `/api/v2/system_settings/` with an admin-scoped token. The operator runs it once per install, and rerunning it changes nothing. The token handling follows the Phase 27 idiom: a 0600 header file, never on argv, https-only and TLS verified (ADR-025). The script does not change `security.yml`.

#### Proof
- **D-11:** Extend the **kind proof now**: `scripts/defectdojo-import-proof.sh`, on top of the Phase 26 chart with the new values and the bootstrap script. The API assertions cover:
  - PR-branch findings that exist on the default branch are marked duplicates, and the PR engagement's active findings are only the new ones;
  - SCA cross-tool collapse works, or the measured gap per D-07;
  - False Positive, Risk Accepted and Out of Scope dispositions on the default-branch engagement **survive a reimport** and are not reactivated;
  - the D-02 orphan case after a PR engagement delete is healed by the next default-branch reimport, or the D-03 fallback is proven;
  - the bootstrap script is idempotent: a second run produces no change.
- **D-12:** The proof runs **both locally on kind and as a real GitHub Actions run**, through the existing path-filtered proof workflow. This is the same evidence standard as 27 D-19.

#### Triage workflow
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

#### Records (required, not discretionary)
- **D-18:** Write **ADR-026** (dedup scope, the cross-tool decision and its measured outcome, config homes, triage system of record, dispositions, and SLA excluded) and add its row to `docs/adr/README.md`. ADRs are append-only, so do not edit ADR-023/024/025.
- **D-19:** In `kubernetes/defectdojo/README.md`, change the rows for DDOJO-03 and DDOJO-04 (currently "Planned (Phase 28)", lines 52-53) to their delivered status. Mark DDOJO-03/04 Complete in `.planning/REQUIREMENTS.md`.

### Claude's Discretion
- The bootstrap script name, the runbook file name and location inside `security-platform`, and the exact assertion structure in the proof script.
- The exact hash-field set per scanner, within the limits of D-05 and D-07.
- How "Under Review" maps onto DefectDojo fields (D-15).
- Whether the release needs a new security-platform tag. A tag is required only if `security.yml` or the callers change; a chart-only or script-only change follows the chart's own versioning.

### Deferred Ideas (OUT OF SCOPE)
- SLA tracking and days-to-fix per severity: excluded by the operator (D-16). Revisit if a reporting need appears.
- Automating the hash recompute through a chart hook Job (D-08 chose documentation only).
- Cross-tool dedup for IaC (Checkov/tflint) and secrets (Semgrep/Gitleaks): not attempted (D-05).
- Syncing DefectDojo dispositions to GitHub code scanning alerts: a new capability.
- A token and role model for multiple triagers (DefectDojo groups and permissions): not discussed; single-operator practice.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DDOJO-03 | Deduplication rules configured so repeated findings across scans/tools collapse rather than duplicate | Product-wide hash/uid dedup across engagements and test types is verified in source (§Architecture Patterns 1). Dedup is **off on a fresh install** and must be switched on by the bootstrap script (§Pitfall 1). Cross-tool SCA collapse is **not achievable** in 3.3.200, measured against the fixtures (§Cross-Tool Measurement), so D-07 applies. The D-02 orphan never happens, because the engagement DELETE re-parents it (§Pattern 3). |
| DDOJO-04 | Triage workflow documented/configured for reviewing and dispositioning findings in DefectDojo | Reimport never reactivates False Positive, Out of Scope or Risk Accepted findings, and no flag is needed. FP and OOS are additionally stamped Mitigated on the first reimport (§Pattern 4). A disposition on the default-branch original suppresses PR duplicates (§Pattern 5). The Under Review mapping, the Risk Acceptance API and its model limits, and the System Settings API shape and permission are covered in §Patterns 6-7 and §Code Examples. |
</phase_requirements>

## Summary

**Source basis.** Every `[VERIFIED: 3.3.200 src ...]` claim was read in a `git clone --depth 1 --branch 3.3.200 https://github.com/DefectDojo/django-DefectDojo` checkout. That tag is commit `395f040530891acc1ca5642785b03d51ff25c8b6` and `dojo/__init__.py` reads `__version__ = "3.3.200"`. Chart claims were read in the vendored `kubernetes/defectdojo/charts/defectdojo-1.9.53.tgz`, and the wrapper chart was rendered with `helm template`. Latest docs were not used for any setting name.

The pinned 3.3.200 source answers four of the CONTEXT questions with no `security.yml` change. (1) **D-02's orphan never happens.** `Engagement.delete()` calls `prepare_duplicates_for_delete()`. That function re-parents every duplicate outside the deleted scope whose original sits inside it, synchronously and during the same DELETE call. The lowest-id outside duplicate becomes the new original, with `duplicate=False`. So the operator's "the next reimport heals it" model is wrong in the harmless direction: the heal happens at delete time, with no window. The D-03 fallback is not needed. (2) **D-15 needs no flag, and the hard requirement holds: FP, OOS and RA are never reactivated.** Reimport checks the disposition flags *before* `is_mitigated` and never sets `active=True` on a dispositioned finding. `do_not_reactivate` only gates re-appearing *mitigated* findings, and reactivating those on regression is the behaviour the operator wants. **One state change the runbook must describe:** a still-reported **FP or OOS** finding is additionally stamped **Mitigated** (`is_mitigated=True`, `mitigated=<scan date>`, note "Mitigated by <type> re-upload.") by `close_old_findings` on the first reimport after the disposition. Its flag is kept, it stays inactive, and nothing reactivates it afterwards. **Risk Accepted** findings are explicitly protected and stay unchanged. See Pattern 4. (3) **D-14 holds.** New findings are deduplicated against originals whatever their disposition. Only mitigated, not-human-dispositioned originals refuse a new duplicate, and that refusal is the correct regression behaviour. (4) Because of (1) and (2), **no new v1.x tag is required.** The release is chart plus scripts plus docs.

The **cross-tool SCA goal (D-05) is not achievable in 3.3.200**, so **D-07 applies**. I ran the three scanners with the exact security.yml flags against `fixtures/`, and the parsers make it structurally impossible. `NPM Audit v7+ Scan` sets no `vulnerability_ids` and no `component_version`, its `component_name` is `node_modules/lodash`, and it emits one finding per package, not one per CVE. `pip-audit Scan` stores only pip-audit's primary id (`PYSEC-2018-28`) and drops the aliases, while Trivy stores `CVE-2018-18074` for the same advisory. No combination of `HASHCODE_ALLOWED_FIELDS` collapses these correctly. `component_name` + `component_version` alone would over-collapse, merging 5 distinct requests advisories into 1. That leaves D-09 with no cross-tool substance. I recommend a reduced but still useful D-09 (see Open Question 1): restate `DD_DUPLICATE_CLUSTER_CASCADE_DELETE=False` as a guard, because `True` would make the PR-engagement DELETE also delete default-branch findings. Also restate the 3.3.200 `DD_DEDUPLICATION_ALGORITHM_PER_PARSER` values for the 7 imported scan types, as drift defence on a version bump. Do not add `DD_HASHCODE_FIELDS_PER_SCANNER` entries.

The **bootstrap script** is simple but has three traps. `/api/v2/system_settings/` requires a **superuser**. The Phase 27 `ci-importer` is deliberately staff but not superuser, so the script needs a different token. `enable_deduplication` is **False** on a fresh install (the fixture loaded by `complete_initialization`, row `pk=1`). And the API, unlike the UI, does **not** refuse `enable_deduplication=true` together with `false_positive_history=true`, so the script must set both FP-history flags to false explicitly. Deduplication runs **asynchronously by default**, so the proof must wait for it, not assert straight after the HTTP 201.

**Primary recommendation:** Ship three things. (a) `defectdojo.extraConfigs` defaults: `DD_DUPLICATE_CLUSTER_CASCADE_DELETE: "False"` plus the restated algorithm map, both gated as JSON or boolean in `check-defectdojo-chart.sh`. (b) `scripts/defectdojo-configure.sh`, which does a read-compare-PATCH of `enable_deduplication=true, delete_duplicates=false, false_positive_history=false, retroactive_false_positive_history=false`, uses a superuser token and is idempotent. (c) A new proof block that runs **after** the Phase 27 assertions, in a **fresh product**, with `ci-importer` switched to `deduplication_execution_mode=async_wait`, and asserts dedup, disposition survival, delete-time re-parent and idempotency. Record the D-07 gap, as measured, in ADR-026.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Dedup algorithm and hash fields per scan type | K8s config (chart `extraConfigs` → ConfigMap → env) | — | Read once at Django settings import (`settings.dist.py:1498`, `:1959`), so it is process config, not DB state |
| Dedup on/off, FP history, delete-duplicates | Database (System_Settings row, pk=1) | Bootstrap script (API writer) | DB-level singleton, editable only via API/UI by a superuser |
| Duplicate marking | Celery worker (async post-processing) | Django web (sync/async_wait modes) | `do_dedupe_batch_task` is a Celery task; the mode is per-user or per-request |
| Duplicate-cluster re-parent on PR delete | Django web (inside the engagement DELETE request) | — | `Engagement.delete()` → `prepare_duplicates_for_delete` runs in-request when `ASYNC_OBJECT_DELETE=False` (the default) |
| Disposition persistence across reimport | Django web (reimporter) | — | `default_reimporter.process_matched_finding` |
| Risk-acceptance expiry | Celery beat (`risk_acceptance_expiration_handler`, every 3 h) | — | `settings.dist.py:1083-1085` |
| Triage procedure | Documentation (runbook in security-platform) | DefectDojo UI | D-13, D-17 |
| Proof | kind cluster on runner + harness | GitHub Actions workflow | D-11, D-12 |

## Standard Stack

No new libraries or packages. Every piece reuses what Phases 26 and 27 already pinned.

### Core
| Component | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| DefectDojo app | 3.3.200 (pinned, ADR-023) | Dedup engine, reimport, System Settings and Risk Acceptance APIs | Already deployed by the Phase 26 chart |
| Upstream chart | 1.9.53 (vendored tgz) | `extraConfigs` → ConfigMap → `envFrom` into django, celery-worker, celery-beat, initializer | Verified in the rendered templates |
| python3 stdlib + curl | runner/system | Bootstrap script client (the Phase 27 idiom) | Same 0600 header-file token handling as `security.yml` |
| kind + Helm v4.3.0 + yq + jq | as pinned in the proof workflow | Proof harness | Existing Phase 26/27 harness |

**Installation:** none.

## Package Legitimacy Audit

This phase installs no external packages: no npm, PyPI or crates dependencies are added. The scripts use `curl`, `python3` stdlib, `jq` and `yq`, all already required by the Phase 26/27 harness. slopcheck was not run because there is nothing to check.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Cross-Tool Measurement (D-05 / D-07)

This is the measured basis for the D-07 decision. `[VERIFIED: measured locally 2026-09-25]` Scanner versions were trivy 0.74.0, pip-audit 2.10.1 and npm 11.7.0, with the same flags security.yml uses. Trivy ran with `--skip-db-update` against the local DB, so the counts are local. The id-namespace conclusion does not depend on DB freshness. The D-11 live run records the canonical numbers.

| Parser (scan_type) | `vulnerability_ids` | `component_name` | `component_version` | Findings per | Source |
|---|---|---|---|---|---|
| `Trivy Scan` (trivy fs, `--severity HIGH,CRITICAL`) | `[VulnerabilityID]`, e.g. `CVE-2018-18074`, `NSWG-ECO-516` | `PkgName`, e.g. `lodash`, `requests` | `InstalledVersion` | CVE × package | `dojo/tools/trivy/parser.py:294-394` |
| `NPM Audit v7+ Scan` | **not set** | `nodes[0]`, e.g. `node_modules/lodash` | **not set** | **package** (only `via[0]`, keyed on title+severity) | `dojo/tools/npm_audit_7_plus/parser.py:88-170` |
| `pip-audit Scan` | `[vuln.id]` only, e.g. `PYSEC-2018-28`; **aliases ignored** | `name`, e.g. `requests` | `version` | advisory × package | `dojo/tools/pip_audit/parser.py:59-110` |

The same vulnerability, measured:
- requests 2.19.1: Trivy `CVE-2018-18074`, pip-audit `PYSEC-2018-28` (aliases `GHSA-x84v-xcm2-53pg`, `CVE-2018-18074`). **No shared `vulnerability_ids` value.**
- lodash 4.17.15: Trivy reports 4 findings (`CVE-2020-8203`, `CVE-2021-23337`, `CVE-2026-4800`, `NSWG-ECO-516`). npm audit reports **1** finding: title `Command Injection in lodash`, `component_name=node_modules/lodash`, `vuln_id_from_tool=1106913`, and the GHSA only inside `references`.

**Conclusion `[VERIFIED]`.** No subset of `HASHCODE_ALLOWED_FIELDS` (`settings.dist.py:1583`) yields equal hashes for the same vulnerability across these parsers without also merging distinct vulnerabilities. The hash is `sha256(casefold(concat(fields)))` (`dojo/finding/models.py:1030-1040`), so there is no fuzzy matching. D-07 applies, and ADR-026 records this table.

## Architecture Patterns

### System Architecture Diagram

```
 GitHub run (PR or schedule)                       DefectDojo 3.3.200 (chart 1.9.53)
 ───────────────────────────                       ─────────────────────────────────
 defectdojo-import job ──reimport-scan (async)──▶ Reimporter: match WITHIN the same Test
   (engagement ci/<branch>)                          │  existing FP/OOS/RA ─▶ unchanged (never reactivated)
                                                     │  existing mitigated  ─▶ reactivate (regression)
                                                     │  missing from report ─▶ close_old_findings ─▶ Mitigated
                                                     │  unmatched            ─▶ new Finding
                                                     ▼
                                          Celery post-processing: dedupe_batch_of_findings
                                            if System_Settings.enable_deduplication (DB, default FALSE)
                                            candidates = same PRODUCT, all engagements with
                                                         deduplication_on_engagement=False,
                                                         any test_type (hash), same test_type (uid),
                                                         duplicate=False, lower id
                                            match ─▶ new.duplicate=True, active=False, verified=False
                                                        (original keeps its disposition)
 defectdojo-cleanup job ──DELETE engagement──▶ Engagement.delete()
   (ci/<PR branch>)                              └─ prepare_duplicates_for_delete():
                                                    for each in-scope original with outside duplicates:
                                                      lowest-id outside dup ─▶ new original
                                                      (copies active/verified/is_mitigated ONLY)
                                                      other dups re-pointed to it
                                                  └─ cascade delete Tests/Findings

 Chart values ─ defectdojo.extraConfigs ─▶ ConfigMap <fullname> ─envFrom─▶ django(uwsgi), celery-worker,
                                                                         celery-beat, initializer
 Bootstrap script ── superuser token ── PATCH /api/v2/system_settings/1/ ─▶ System_Settings row
 Triager (UI) ── on ci/<default> only ─▶ FP / OOS (finding PATCH) · Risk Acceptance (RA object w/ expiry)
```

### Recommended file layout (security-platform)
```
kubernetes/defectdojo/
├── values.yaml        # + defectdojo.extraConfigs defaults with WHY-comments (D-09)
├── README.md          # DDOJO-03/04 rows, the "Dedup and triage" section, the D-08 recompute note, a bootstrap step
└── TRIAGE.md          # triage runbook (D-17)
scripts/
├── defectdojo-configure.sh         # NEW idempotent System Settings bootstrap (D-10)
├── check-defectdojo-chart.sh       # + extraConfigs assertions (the count literal moves in 3 places)
└── defectdojo-import-proof.sh      # + Phase 28 proof block (D-11)
.github/workflows/defectdojo-import-proof.yml   # + scripts/defectdojo-configure.sh in paths:
```
This repository: `docs/adr/adr026-*.md`, the `docs/adr/README.md` row, the `docs/adoption-guide.md` link, and `.planning/REQUIREMENTS.md`.

### Pattern 1: Product-wide dedup across engagements and test types `[VERIFIED: 3.3.200 src]`
- Candidate scope for dedup: `Q(test__engagement__product=product) & (Q(test__engagement=eng) | Q(test__engagement__deduplication_on_engagement=False))`, in `dojo/finding/deduplication.py:386-395`. With D-01 (flag false everywhere), that is the whole product.
- The hash-code candidates are **not** filtered by `test_type` (`deduplication.py:441-446`), so different scanners *can* collapse if their `hash_code` is equal. The unique-id candidates *are* restricted to the same `test_type` (`:474-475`, `:507-508`).
- Candidates exclude `duplicate=True` (`:445`). Only an older (lower-id) candidate can become the original (`_is_candidate_older`, `:630-644`). Transitive chains are flattened (`set_duplicate`, `:131-210`).
- Marking sets `duplicate=True, active=False, verified=False, duplicate_finding=original` (`:180-184`) and adds the new test_type to `original.found_by`.
- Location gate: `are_locations_duplicates` compares **URL** locations only (`:309-353`, `finding_locations` `:263-274`). SCA, IaC and secrets findings carry no URL locations, so both lists are empty and the comparison returns True. Hash equality is then the sole criterion.
- Effective algorithms for the imported scan types, all from `settings.dist.py`:

| scan_type (security.yml TABLE) | Algorithm | Hash fields |
|---|---|---|
| `Semgrep JSON Report` | `unique_id_from_tool_or_hash_code` (:1782) | none configured, so **legacy** hash `title+cwe+line+file_path+description`. Semgrep CE fingerprint is `requires login`, which the parser maps to None (`tools/semgrep/parser.py:99-105`) |
| `Checkov Scan` | `hash_code` (:1756) | none, so **legacy** |
| `Trivy Scan` (fs and image) | `hash_code` (:1744) | `title, severity, vulnerability_ids, cwe, description` (:1205) |
| `Gitleaks Scan` | `hash_code` (:1815) | none, so **legacy** |
| `NPM Audit v7+ Scan` | `hash_code` (:1728) | `title, severity, cwe, vuln_id_from_tool` (:1189) |
| `pip-audit Scan` | `hash_code` (:1816) | `vuln_id_from_tool, component_name, component_version` (:1233) |
| `SARIF` (tflint) | `unique_id_from_tool_or_hash_code` (:1776) | none, so **legacy** |

A parser's `get_dedupe_fields()` methods are **documentation only**: nothing outside `dojo/tools/` calls them (grep verified). Only the settings dicts count.

### Pattern 2: Settings override via chart `extraConfigs` `[VERIFIED: chart 1.9.53 + helm template]`
- Upstream key: top-level `extraConfigs: {}` (subchart `values.yaml:659-666`), rendered verbatim into the main ConfigMap (`templates/configmap.yaml`, `{{- with .Values.extraConfigs }} {{- toYaml . | nindent 2 }}`).
- In the wrapper it is `defectdojo.extraConfigs.<KEY>`. Rendered and verified: `--set-json 'defectdojo.extraConfigs={"DD_DEDUPLICATION_ALGORITHM_PER_PARSER":"{\"Trivy Scan\": \"hash_code\"}"}'` produces `.data.DD_DEDUPLICATION_ALGORITHM_PER_PARSER` in ConfigMap `defectdojo`.
- It is consumed via `envFrom: configMapRef` by `defectdojo-django` (uwsgi), `defectdojo-celery-worker`, `defectdojo-celery-beat` and the initializer job. The celery worker matters most, because dedup runs there.
- A change rolls the pods: django, worker and beat each carry `checksum/config` of `configmap.yaml`.
- Env names and parsing, from `settings.dist.py`:
  - `DD_HASHCODE_FIELDS_PER_SCANNER` (str, default `""`, :280). It is `json.loads`'d and must be `{scan_type: [field,...]}`, or settings import raises `TypeError` / `AttributeError` (:1498-1512). Keys are **merged** into the shipped dict, replacing or adding entries.
  - `DD_DEDUPLICATION_ALGORITHM_PER_PARSER` (str, default `""`, :282). It is `json.loads`'d. The values must be one of `legacy | unique_id_from_tool | hash_code | unique_id_from_tool_or_hash_code`, or it raises `AttributeError` (:1959-1970). Keys are merged.
  - `DD_DUPLICATE_CLUSTER_CASCADE_DELETE` (bool, default False, :243 / :2150).
  - Alternatives not recommended: `localsettingspy` (a mounted `local_settings.py`, which is arbitrary Python) and `extraEnv` (container env list). `extraConfigs` is the documented non-secret key/value path.

### Pattern 3: Engagement DELETE re-parents duplicate clusters, so D-02 never orphans `[VERIFIED: 3.3.200 src]`
- `EngagementViewSet.destroy` calls `instance.delete()` when `ASYNC_OBJECT_DELETE` is False, which is the default (`dojo/engagement/api/views.py:86-93`, `settings.dist.py` `DD_ASYNC_OBJECT_DELETE=(bool, False)`). The async path also calls it (`dojo/utils.py:1928`).
- `Engagement.delete()` calls `finding_helper.prepare_duplicates_for_delete(self)` before `super().delete()` (`dojo/engagement/models.py:204-208`).
- `prepare_duplicates_for_delete` (`dojo/finding/helper.py:813-908`):
  1. resets duplicates that are inside the scope;
  2. for each original inside the scope that has duplicates outside it, runs `reconfigure_duplicate_cluster(original, outside)` (`:781-810`). The **lowest-id outside duplicate** becomes the original: `duplicate=False, duplicate_finding=None, active=original.active, verified=original.verified, is_mitigated=original.is_mitigated`. `found_by` is copied, and the remaining outside duplicates are re-pointed to it.
  3. only when `DUPLICATE_CLUSTER_CASCADE_DELETE=True` does it **delete** the outside duplicates instead, which would destroy default-branch findings. Hence the recommended guard default.
- **Consequence for D-02:** the default-branch copy is an active original again **immediately** after the cleanup DELETE returns 204, provided the PR original was active. No 24 h window, no reimport needed, **no D-03 fallback, no security.yml change**.
- **Caveat A (verified):** the re-parent copies only `active`, `verified` and `is_mitigated`. It never copies `false_p`, `risk_accepted` or `out_of_scope`, and not the `mitigated` datetime either. Suppose someone dispositioned the PR-engagement original as FP. The default-branch copy then becomes `active=False`, not FP, not mitigated: an un-dispositioned limbo. The next reimport's `process_matched_active_finding` never sets `active=True` (`default_reimporter.py` ~L1194-1270), so it stays hidden. This is the concrete, code-level reason D-14's "triage on `ci/<default>` only" is a **hard rule**. The runbook must say so.
- **Caveat B (verified):** "lowest-id outside duplicate" can be **another open PR's** copy rather than the default branch's. The default-branch copy then stays a duplicate until that PR's engagement is deleted in turn, when it is re-parented again. This transient is bounded by PR lifetime. Document it; no action needed.
- **Caveat C (verified):** if the PR original was already `is_mitigated` (closed by its own reimport), the new original gets `is_mitigated=True, active=False, mitigated=None`. The next default-branch reimport sees `is_mitigated` and reactivates it (`process_matched_mitigated_finding`, `do_not_reactivate` false), so it self-heals within one scheduled run.

### Pattern 4: Reimport never reactivates FP / OOS / Risk Accepted, and needs no flag `[VERIFIED: 3.3.200 src]`
- Reimport matches only within the **same Test** (`build_candidate_scope_queryset(mode="reimport")` returns `Finding.objects.filter(test=test)`, `deduplication.py:383-385`).
- `process_matched_finding` (`default_reimporter.py` ~L1023): `if existing.false_p or existing.out_of_scope or existing.risk_accepted` routes to `process_matched_special_status_finding` (~L1047-1081). This check runs **before** the `is_mitigated` check, so a dispositioned finding can never reach the reactivation code in `process_matched_mitigated_finding`. `active` is never set True on this path. **Reactivation: impossible for FP, OOS and RA. VERIFIED.**
- Inside `process_matched_special_status_finding` there are three branches:
  1. The existing and parsed `false_p/out_of_scope/risk_accepted` all equal: append to `unchanged_items` and `continue`. This **never fires for our parsers**, because Trivy, pip-audit and npm-audit emit `false_p=False` and friends, while the dispositioned row has True.
  2. `existing.risk_accepted and not existing.active`: append to `unchanged_items` (the code comment: "as otherwise it will get mitigated by the reimporter"). **RA is fully protected.**
  3. Otherwise, which is the **FP / OOS case**: return `(existing, False)` **without** appending to `unchanged_items`.
- `to_mitigate = original_items - reactivated_items - unchanged_items` (~L578). A still-reported FP/OOS finding is therefore in `to_mitigate`. `close_old_findings` (~L850-900) refreshes the three flags from the DB (`_sync_close_old_finding_status_fields`, #12291). Then `if not finding.mitigated or not finding.is_mitigated` calls `mitigate_finding` (`base_importer.py:1229-1266`). That sets `active=False, is_mitigated=True, mitigated=scan_date, mitigated_by=<import user>`, adds the note "Mitigated by <test_type> re-upload." and calls `risk_unaccept`, which is a no-op when `risk_accepted` is False. **It does not touch `false_p` or `out_of_scope`.** On later reimports the finding is already mitigated, so it is skipped.
- **Net verified outcome** after the first reimport following a disposition, when the scanner still reports the finding:
  - FP: `false_p=True, active=False, is_mitigated=True`
  - OOS: `out_of_scope=True, active=False, is_mitigated=True`
  - RA: `risk_accepted=True, active=False, is_mitigated=False`

  None is reactivated, then or ever: the special-status check precedes the mitigated check. This is source-derived, and P-DISPOSITION must assert the exact tuple, `is_mitigated` included, so a behaviour change cannot pass silently.
- Consequence for D-14 (Pattern 5): an FP/OOS original that is now `is_mitigated=True` still accepts PR duplicates, because `is_duplicate_reopen` requires `finding_not_human_set_status`, which is False for FP and OOS. Suppression holds.
- Upstream note: `unittests/test_import_reimport.py::test_import_reimport_keep_false_positive_and_out_of_scope` sets `is_mitigated=True` together with the disposition before reimporting, so it does not exercise this exact path. The kind proof is the evidence.
- `do_not_reactivate` (ReImportScanSerializer, default False, `api_v2/serializers.py:766-769`) is checked **only** in `process_matched_mitigated_finding`. It suppresses reactivation of Mitigated findings that re-appear. Leave it **off**, because a regression must reopen. **No `security.yml` change.**
- `close_old_findings=true` (the reimport default is True, `serializers.py:779-786`, and security.yml sends it explicitly) also mitigates dispositioned findings that are **no longer in the report**. For RA, `mitigate_finding` → `risk_unaccept` removes the acceptance ("the scan no longer reports this finding"), matching `test_reimport_closes_risk_accepted_when_vulnerability_fixed`. FP and OOS keep their flags.
- Reimport does not pass `verified`, so `self.verified is None` and the existing finding's `verified` is preserved (options `validate_verified` default None, `importers/options.py:617-626`). A triager's "Verified" survives reimport.

### Pattern 5: A disposition on the default-branch original suppresses PR duplicates (D-14) `[VERIFIED: 3.3.200 src]`
- A new PR finding, necessarily newer if the default branch imported first, is matched to the default-branch original whatever that original's `false_p/risk_accepted/out_of_scope`. The candidate query excludes only `duplicate=True`.
- `set_duplicate` refuses only when `is_duplicate_reopen`: the original is mitigated, *not* human-dispositioned (`out_of_scope=False and false_p=False`), and the new finding is not mitigated (`deduplication.py:213-222`). In that case the PR finding stays **active**, which correctly surfaces a regression of a fixed issue.
- Result: FP, OOS and RA originals get their PR copies as inactive duplicates, so the PR engagement's active list shows only what the PR introduces.
- `false_positive_history` is a *separate* mechanism that marks equal findings FP. The **UI refuses** it together with dedup (`system_settings/ui/views.py:64-68`), but the **API serializer does not validate** it (`fields="__all__"`, no `validate`). Keep it **false**; dedup already provides the suppression.

### Pattern 6: The "Under Review" mapping (discretion)
DefectDojo has a native `Finding.under_review` boolean plus `review_requested_by` and `reviewers` (`dojo/finding/models.py:247-270`), and `status()` prints "Under Review" when it is set (`:1096`). Nothing in import or reimport sets it: `reimport-scan` has no such field.

**Recommendation `[ASSUMED — operator to confirm]`:** "Under Review" is the **native untriaged queue**, the implicit state every newly imported finding lands in: `active=true, verified=false, false_p=false, out_of_scope=false, risk_accepted=false, duplicate=false, is_mitigated=false`, on engagement `ci/<default>`. The runbook gives the filter (UI) and the API query `GET /api/v2/findings/?test__engagement=<id>&active=true&verified=false&false_p=false&out_of_scope=false&risk_accepted=false&duplicate=false`. Triage exits the state by setting Verified (→ Verified/Active) or one of FP / OOS / RA. The native `under_review` flag is the peer-review request workflow (reviewers, multiple triagers), which is the deferred multi-triager idea. Mention it as optional, not required. Why: zero automation, it survives reimport (reimport never sets `verified`), and every new finding is in the state by construction. The explicit flag would need a bulk action after every import.

### Pattern 7: Risk acceptance mechanics `[VERIFIED: 3.3.200 src]`
- There is **no system-wide "enable risk acceptance" setting.** It is per **Product**: `enable_full_risk_acceptance=True` and `enable_simple_risk_acceptance=False` by default (`dojo/product/models.py:123-124`). Products are auto-created by the import, so the defaults apply, and full RA (a Risk_Acceptance object with expiry) is the only path. Simple RA (a checkbox with no expiry) is refused at the API: "Simple risk acceptance is disabled for this product" (`finding/api/serializer.py:630-637`). The runbook says: do not enable simple RA.
- `Risk_Acceptance.expiration_date` and `decision_details` are **nullable** (`risk_acceptance/models.py:47,55`). "Mandatory expiry and reason" is **a runbook rule, not a model constraint**. The only system-level knob is `risk_acceptance_form_default_days` (default 180), which pre-fills the UI form's expiry. `risk_acceptance_notify_before_expiration` (default 10) is a notification setting, and D-16 excludes notifications.
- On expiry, the Celery beat task `dojo.risk_acceptance.helper.expiration_handler` runs every 3 h (`settings.dist.py:1083-1085`). With `reactivate_expired=True` (the default) it sets `active=True, risk_accepted=False`, and the finding re-enters Under Review because verified stays false unless `restore_verified_expired`.
- API: `POST /api/v2/risk_acceptance/` with `name`, `owner` (user id, required FK), `accepted_findings` (all from **one** engagement, else 403), `expiration_date`, `decision` (default `A`), `decision_details` (the reason). `add_findings_to_risk_acceptance` sets `active=False, risk_accepted=True` (`risk_acceptance/helper.py` ~L244-246).

### Anti-Patterns to Avoid
- **Triage on a `ci/<PR>` engagement.** The disposition is lost on delete (Caveat A) and the default-branch copy is stranded inactive.
- **`DD_DUPLICATE_CLUSTER_CASCADE_DELETE=True`.** The PR cleanup DELETE would then also delete the default-branch duplicates of that PR's findings.
- **Enabling `false_positive_history` alongside dedup through the API.** The UI forbids the combination; the API silently allows it.
- **Adding `DD_HASHCODE_FIELDS_PER_SCANNER` entries for Checkov / Gitleaks / Semgrep / SARIF as a "restatement".** They have no entry today, so they use `compute_hash_code_legacy`. Adding an entry switches them to the configured path. That is a hash change for every existing finding, not a restatement.
- **`do_not_reactivate=true` on the reimport.** It would stop regressions of fixed findings from reopening.
- **Asserting dedup state straight after the reimport 201.** Dedup is async by default.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Re-parenting duplicates before a PR delete (D-03) | A cleanup-job pre-pass | Nothing: `Engagement.delete()` already does it | Verified in source, Pattern 3 |
| Keeping dispositions through reimport | A reimport flag or post-import fix-up | Native special-status handling | Pattern 4 |
| Cross-tool CVE normaliser | An alias-mapping pre-processor | Nothing (D-07) | Operator ruled it out; the gap is measured |
| Hash recompute after a settings change | A custom job | `python manage.py dedupe` (upstream) | D-08 |
| Expiry of risk acceptances | A cron job | Celery beat `risk_acceptance_expiration_handler` | Built in, every 3 h |
| System settings diffing | A PUT of the full object | GET, compare the 4 keys, PATCH only the drifted keys | Idempotent, minimal blast radius |

## Runtime State Inventory

Not a rename phase. One runtime-state item exists because the phase changes DB-level configuration on existing installs:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Existing installs: none (the homelab install is Phase 29). Kind: ephemeral | If hash fields ever change on a live install, run `manage.py dedupe` (D-08, documentation only) |
| Live service config | System_Settings row pk=1 (DB, not git) | Bootstrap script; rerun after any fresh install |
| OS-registered state | None, verified: no cron or systemd involved | none |
| Secrets/env vars | The bootstrap needs a **superuser** token, not the CI `DEFECTDOJO_API_TOKEN` | Document as an operator-held credential; never stored in the repo |
| Build artifacts | None | none |

## Common Pitfalls

### Pitfall 1: Dedup is OFF on a fresh install
**What goes wrong:** the chart ships, imports run, and nothing is ever marked duplicate.
**Why:** `System_Settings.enable_deduplication` defaults to False. `complete_initialization` loads fixture `system_settings.json` (`pk=1`, `enable_deduplication=false`) (`management/commands/complete_initialization.py:166-170`, `fixtures/system_settings.json`).
**Avoid:** the bootstrap script is a mandatory post-install step. Put it in the README install sequence and in Phase 29.
**Warning sign:** `GET /api/v2/system_settings/` shows `enable_deduplication: false`.

### Pitfall 2: The System Settings API is superuser-only
**What goes wrong:** the bootstrap using the Phase 27 `ci-importer` token (staff, non-superuser) gets 403.
**Why:** `SystemSettingsViewSet.permission_classes = (permissions.IsSuperUser, DjangoModelPermissions)` (`system_settings/api/views.py:16`).
**Avoid:** document a separate superuser token for the bootstrap. This is a deliberate split, not a regression of 27 D-10. Never put this token in GitHub secrets.

### Pitfall 3: Dedup is asynchronous
**What goes wrong:** proof assertions read `duplicate=false` because Celery has not run yet.
**Why:** `Dojo_User.resolve_deduplication_execution_mode` defaults to `async` (`user/models.py:53-69`). The request override `deduplication_execution_mode` (async | async_wait | sync) is not sent by security.yml.
**Avoid:** in the harness only, PATCH `ci-importer`'s `/api/v2/user_contact_infos/<id>/` `deduplication_execution_mode=async_wait`. This keeps the Celery path but makes the 201 wait for dedup. Also bound-poll (≤120 s) as a belt-and-braces measure. Do not add the field to security.yml, which would be a v1.x change.

### Pitfall 4: A malformed JSON settings value crash-loops every pod
**Why:** `json.loads` plus type validation at settings import (`settings.dist.py:1498-1512`, `:1959-1970`).
**Avoid:** `check-defectdojo-chart.sh` asserts that the rendered ConfigMap value parses as JSON (`jq -e`) and that every algorithm value is one of the 4 allowed strings. This also puts `jq` to use (26-REVIEW IN-03).

### Pitfall 5: The gate count literal moves in 3 places
`check-defectdojo-chart.sh` says "20 offline invariants" in the header comment, in the `asserting ...` echo and in `CHECK_COUNT` (file header lines 18-20). New checks must bump all three in one commit.

### Pitfall 6: The proof workflow paths filter misses the new script
`defectdojo-import-proof.yml` `paths:` lists `scripts/defectdojo-import-proof.sh`, `scripts/defectdojo-live-smoke.sh` and `kubernetes/defectdojo/**`, but not a new `scripts/defectdojo-configure.sh`. Add it, or a change to the bootstrap never triggers the proof.

### Pitfall 7: The Phase 27 harness imports identical reports to both branches
**What goes wrong:** a "PR has only new findings" assertion passes vacuously, with 0 new findings, or proves nothing.
**Avoid:** the Phase 28 block needs a **delta**. Import the default branch first, then the PR with the same reports **plus one extra report or finding** that main lacks (for example a PR-only Gitleaks report or a trimmed trivy-fs copy on main). Assert that exactly the delta is active on the PR and that everything else is duplicate.

### Pitfall 8: Legacy-hash scanners are line-sensitive
Checkov, Gitleaks, Semgrep and SARIF use `title+cwe+line+file_path+description`. A PR that shifts lines above an existing issue shows it as "new" on the PR engagement. This is upstream behaviour, and D-05 keeps these within-tool. Document it in the runbook ("expected noise"). Do not change the hash fields.

### Pitfall 9: The FP-history and dedup combination
Covered in Pattern 5. The bootstrap sets both FP-history flags false explicitly, and the proof asserts it.

### Pitfall 10: SLA is already ON upstream
`enable_finding_sla` defaults to **True** (`system_settings/models.py:199-203`). D-16 says "do not enable SLA". It is not being enabled, it is simply on. See Open Question 2. SLA *notifications* (`enable_notify_sla_*`) default False.

## Code Examples

### Chart defaults (values.yaml), recommended shape
```yaml
  # -- Non-secret DefectDojo Django settings, rendered into the main ConfigMap
  # and read at settings import by django, celery-worker, celery-beat and the
  # initializer (upstream chart 1.9.53 `extraConfigs`). Values are STRINGS.
  extraConfigs:
    # -- MUST stay "False" (ADR-026): with True, deleting a PR's ci/<branch>
    # engagement (27 D-10) also DELETES default-branch findings that are
    # duplicates of that PR's findings, instead of re-parenting them
    # (dojo/finding/helper.py prepare_duplicates_for_delete, 3.3.200).
    DD_DUPLICATE_CLUSTER_CASCADE_DELETE: "False"
    # -- Restates the 3.3.200 algorithm for every scan_type security.yml imports,
    # so a version bump cannot silently change dedup behaviour. JSON; a malformed
    # value crash-loops every pod (settings.dist.py json.loads).
    DD_DEDUPLICATION_ALGORITHM_PER_PARSER: '{"Semgrep JSON Report": "unique_id_from_tool_or_hash_code", "Checkov Scan": "hash_code", "Trivy Scan": "hash_code", "Gitleaks Scan": "hash_code", "NPM Audit v7+ Scan": "hash_code", "pip-audit Scan": "hash_code", "SARIF": "unique_id_from_tool_or_hash_code"}'
```
(The values were read from `settings.dist.py:1728,1744,1756,1776,1782,1815,1816`. Whether to ship the second key is Open Question 1.)

### Bootstrap: idempotent read-compare-PATCH (python3 stdlib + curl, the Phase 27 idiom)
```python
# Source: SystemSettingsViewSet (List+Update mixins, "Use 'id' 1 for PUT, PATCH"),
# dojo/system_settings/api/views.py:10-21; serializer fields="__all__".
DESIRED = {"enable_deduplication": True, "delete_duplicates": False,
           "false_positive_history": False, "retroactive_false_positive_history": False}
# 1. refuse non-https URL (ADR-025); token -> 0600 header file; curl --proto =https [--cacert]
# 2. GET /api/v2/system_settings/  -> results[0] (exactly one row, id usually 1; use the returned id)
# 3. drift = {k: v for k, v in DESIRED.items() if current.get(k) != v}
# 4. if not drift: print("NO CHANGE"); exit 0
# 5. PATCH /api/v2/system_settings/<id>/  (JSON body = drift only, Content-Type: application/json)
# 6. re-GET and assert every DESIRED key now matches; print "CHANGED: <keys>"
```
An optional `risk_acceptance_form_default_days` key is the operator's call (Open Question 3).

### Dispositions via API (for the proof and the runbook)
```bash
# False Positive  (FP cannot be verified: finding/api/serializer.py:625-627)
PATCH /api/v2/findings/<id>/   {"false_p": true, "active": false, "verified": false}
# Out of Scope
PATCH /api/v2/findings/<id>/   {"out_of_scope": true, "active": false}
# Risk Accepted (full RA; the product default enable_full_risk_acceptance=True)
POST  /api/v2/risk_acceptance/ {"name": "...", "owner": <user_id>, "accepted_findings": [<id>],
                                "expiration_date": "<ISO8601>", "decision": "A",
                                "decision_details": "<reason>"}
```

### Hash recompute after a hash-settings change (D-08 README note)
```bash
# Source: dojo/management/commands/dedupe.py (3.3.200)
kubectl -n <ns> exec deploy/<release-fullname>-django -c uwsgi -- \
  python manage.py dedupe --parser "Trivy Scan" --dedupe_sync
# --hash_code_only   recompute hash_code only
# --dedupe_only      re-run dedup only
# --dedupe_sync      run dedup in the foreground (default: batch tasks to Celery)
# omit --parser to recompute every finding
```
Note: the command excludes `duplicate=True` findings from reprocessing (`dedupe.py` `_run_dedupe`), so existing duplicate links are not re-evaluated. Deployment name `defectdojo-django` and container `uwsgi` were verified by rendering with release `defectdojo`.

## State of the Art

| Old approach | Current (3.3.200) | Impact |
|---|---|---|
| Dedup always synchronous with `block_execution` | Per-user or per-request `deduplication_execution_mode` async / async_wait / sync | Proof must use async_wait or poll |
| Endpoints for dedup location | `V3_FEATURE_LOCATIONS=True` default; only URL locations gate dedup | SCA/IaC findings dedup on hash alone |
| Finding delete could orphan duplicates | `prepare_duplicates_for_delete` re-parents on Test and Engagement delete | D-02 is non-issue |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The operator accepts a reduced D-09 (cascade guard plus algorithm restatement, no hash-field overrides) given that D-05's premise failed | Summary, Open Q1 | Low. The alternative is shipping nothing Django-level, which is also compliant with D-07 |
| A2 | "Under Review" = the implicit untriaged queue (active & !verified & no disposition), not the native `under_review` flag | Pattern 6 | Low. The runbook wording changes; no code |
| A3 | The Trivy local-DB result generalises (the CVE vs PYSEC id mismatch) | Cross-Tool Measurement | Very low: the parser drops aliases whatever the DB contents. The D-11 live run confirms |
| A6 | Triagers accept that FP/OOS findings display as "Mitigated + False Positive/Out of Scope" after the next scan (upstream behaviour, Pattern 4) | Pattern 4, runbook | Low. It is cosmetic; the disposition and inactivity hold |
| A4 | `P-COUNTS` (`statistics.after.total` vs the findings count) is unaffected by dedup | Validation | Medium. It is avoided entirely by running the Phase 28 block after the Phase 27 block, in a fresh product |
| A5 | The PATCH id is 1 on every install (fixture pk=1) | Code Examples | None if the script uses the id returned by GET |

## Open Questions

1. **What does D-09 ship, now that cross-tool dedup is impossible?**
   - Known: no hash-field set achieves SCA collapse (measured). D-07 says ship within-tool plus product-wide.
   - Recommendation: `DD_DUPLICATE_CLUSTER_CASCADE_DELETE: "False"` (a real safety guard for the 27 D-10 delete) plus `DD_DEDUPLICATION_ALGORITHM_PER_PARSER` restating the 7 scan types (drift defence). **No** `DD_HASHCODE_FIELDS_PER_SCANNER`. The gate asserts both. The planner should present this to the operator as the D-07 outcome in ADR-026.
2. **SLA is already enabled upstream (`enable_finding_sla=True`).** D-16 says "do not enable". Options: (a) leave the upstream default, since dispositions work regardless and the runbook ignores SLA columns; (b) have the bootstrap set it False. Recommendation: (a), because it makes no change beyond the phase's scope. Needs operator confirmation either way.
3. **Should the bootstrap set `risk_acceptance_form_default_days`?** The upstream default is 180, which pre-fills the expiry. Recommend leaving it (the runbook makes expiry mandatory) unless the operator wants a shorter default.
4. **Engagement name vs default branch in the proof.** The existing harness uses `main` (`PROOF_DEFAULT_BRANCH`). A fresh Phase 28 product (for example `proof/dedup`) avoids interference with the Phase 27 P-CLEANUP / P-REFUSE assertions on `proof/security-platform`.

## Environment Availability

| Dependency | Required By | Available (local) | Version | Fallback |
|------------|------------|-----------|---------|----------|
| kind | kind proof | ✓ | 0.33.0 | — |
| Helm | chart gate, proof | ✓ | v4.3.0 (CI installs v4.3.0 with a sha256 check) | — |
| yq (mikefarah) | gate, proof extract | ✓ | v4.53.6 | — |
| jq | gate JSON assertion, proof | ✓ | 1.8.2 | — |
| docker | kind | ✓ | 28.3.2 | — |
| kubectl | smoke | ✓ | v1.37.1 | — |
| python3 | bootstrap, proof | ✓ | 3.12.0 | — |
| trivy / pip-audit / npm | proof `scans` job (CI) and local measurement | ✓ | 0.74.0 / 2.10.1 / 11.7.0 | CI job installs its own |
| Live DefectDojo (homelab) | — | ✗ | — | Not needed: Phase 29 |

**Missing dependencies with no fallback:** none.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash assertion harnesses (no unit-test framework): `check-defectdojo-chart.sh` (offline), `defectdojo-import-proof.sh` (kind), `check-adoption-guide.sh` (this repo) |
| Config file | none. The scripts are self-contained |
| Quick run command | `bash scripts/check-defectdojo-chart.sh` (security-platform, offline, < 30 s) |
| Full suite command | `bash scripts/defectdojo-import-proof.sh <reports-dir>` (kind, 15-30 min) plus a GitHub run of `DefectDojo Import Proof` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DDOJO-03 | extraConfigs renders `DD_DUPLICATE_CLUSTER_CASCADE_DELETE=False` and a JSON-valid algorithm map with allowed values only | offline | `bash scripts/check-defectdojo-chart.sh` (new checks) | ✅ extend |
| DDOJO-03 | Bootstrap turns dedup on and FP-history off; the second run reports NO CHANGE with an identical GET body | kind | proof block `P-CONFIGURE` / `P-IDEMPOTENT` | ❌ Wave 0 |
| DDOJO-03 | Main imported first, then the PR with the same reports plus a delta: every PR finding without a delta is `duplicate=true, active=false`; the PR's active set equals the delta | kind | `P-DEDUP-BRANCH` | ❌ Wave 0 |
| DDOJO-03 | Cross-tool SCA: the proof **records** the measured gap (no Trivy↔pip-audit or Trivy↔npm duplicate links across test types) as the D-07 evidence | kind | `P-CROSSTOOL` (asserts the measured outcome, prints the table) | ❌ Wave 0 |
| DDOJO-03 | PR imported first, then main; the PR engagement deleted via the committed dd-delete body: main copies are `duplicate=false, active=true` immediately after the 204, with no reimport | kind | `P-REPARENT` | ❌ Wave 0 |
| DDOJO-04 | FP, OOS and RA set on three main findings; main reimported with the same report (committed dd-import body), **twice**. Exact expected tuples: FP `false_p=T, active=F, is_mitigated=T`; OOS `out_of_scope=T, active=F, is_mitigated=T`; RA `risk_accepted=T, active=F, is_mitigated=F`. None counted as reactivated, and the tuples are unchanged after the second reimport | kind | `P-DISPOSITION` | ❌ Wave 0 |
| DDOJO-04 | Suppression: after the dispositions, a new PR import makes the matching PR copies duplicates, inactive | kind | `P-SUPPRESS` | ❌ Wave 0 |
| DDOJO-04 | Runbook linked from the adoption guide | offline (this repo) | `bash scripts/check-adoption-guide.sh` (new needle) | ✅ extend |
| both | Real GitHub run green | CI | the `DefectDojo Import Proof` workflow (PR path-filtered + dispatch) | ✅ extend `paths:` |

**Proof ordering (recommended):** keep every Phase 27 assertion unchanged, with dedup still off. After P-HTTP, run the bootstrap (admin token), set `ci-importer` to `async_wait`, and run all Phase 28 scenarios in a **fresh product**, using a second product for the reverse-order P-REPARENT case, so the scenarios do not cross-contaminate. Every body run still uses the committed `security.yml` bodies (the single-source rule, T-27-01).

### Sampling Rate
- **Per task commit:** `bash scripts/check-defectdojo-chart.sh`; also `bash scripts/defectdojo-import-proof.sh --extract-only` when the proof script changes.
- **Per wave merge:** a local kind proof run.
- **Phase gate:** the kind proof green locally **and** the GitHub `DefectDojo Import Proof` run green (D-12), plus `bash scripts/check-adoption-guide.sh` green in this repo.

### Wave 0 Gaps
- [ ] `scripts/defectdojo-configure.sh`, which must exist before the proof can call it
- [ ] A delta fixture or report strategy for P-DEDUP-BRANCH (Pitfall 7)
- [ ] `paths:` entry for `scripts/defectdojo-configure.sh` in `defectdojo-import-proof.yml`
- [ ] The gate count literal bump plan (Pitfall 5)

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | DRF token. The bootstrap uses a superuser token read from a 0600 file, never on argv, never echoed |
| V3 Session Management | no | — |
| V4 Access Control | yes | The System Settings API is IsSuperUser. The CI token stays staff non-superuser (27 D-10), and the bootstrap token is operator-held only |
| V5 Input Validation | yes | Settings JSON validated at render by the gate; API values fixed in the script (no user input) |
| V6 Cryptography | no (transport only) | TLS verified, https-only (ADR-025), `--proto =https`, optional `--cacert` |

| Threat | STRIDE | Mitigation |
|---|---|---|
| Superuser token leak via argv or log | Information disclosure | 0600 header file, `-H @file`, no xtrace, removed in `finally` |
| Token sent over http | Information disclosure | Refuse non-https before any request (ADR-025 pattern) |
| Cascade delete of main findings via PR delete | Tampering / DoS of the triage record | `DD_DUPLICATE_CLUSTER_CASCADE_DELETE=False` default plus gate assertion |
| A disposition silently lost | Repudiation / integrity | Triage-on-default-only rule; P-DISPOSITION proof |
| A PR author hiding a finding by disposition | Elevation | Dispositions only on `ci/<default>`; PR engagements are transient (runbook) |

## Project Constraints (from CLAUDE.md)
- This repository is documentation. The executable artifacts land in `OttawaCloudConsulting/security-platform` (the local clone `repos/security-platform/`).
- ADRs are append-only: write the new `adr026-*.md` and do not edit ADR-023/024/025.
- Preserve the 4-phase layered structure and the ASCII diagrams in the primary doc if it is touched.
- Scripts run as `bash script.sh`; never `chmod +x`.
- Failure response: stop, report, wait. No silent fallbacks (`or {}`, `try/except: pass`) in the new scripts.
- `bash scripts/check-adoption-guide.sh` must stay green.

## Sources

### Primary (HIGH confidence)
- DefectDojo `3.3.200` tag, commit 395f040: `dojo/settings/settings.dist.py`, `dojo/finding/deduplication.py`, `dojo/finding/helper.py`, `dojo/finding/models.py`, `dojo/test/models.py`, `dojo/engagement/models.py`, `dojo/engagement/api/views.py`, `dojo/importers/default_reimporter.py`, `dojo/importers/options.py`, `dojo/api_v2/serializers.py`, `dojo/system_settings/{models.py,api/*,ui/views.py}`, `dojo/fixtures/system_settings.json`, `dojo/management/commands/{dedupe.py,complete_initialization.py}`, `dojo/risk_acceptance/{models.py,helper.py,api/serializer.py}`, `dojo/product/models.py`, `dojo/user/models.py`, `dojo/tools/{trivy,npm_audit_7_plus,pip_audit,semgrep,sarif}/parser.py`
- Upstream chart `defectdojo-1.9.53.tgz`: `values.yaml` (extraConfigs/extraEnv/localsettingspy), `templates/configmap.yaml`, `templates/{django,celery-worker,celery-beat}-deployment.yaml`, `templates/initializer-job.yaml`
- `helm template` of the wrapper chart with `--set-json defectdojo.extraConfigs=...` (rendered ConfigMap verified)
- Local scanner runs against `repos/security-platform/fixtures/` (trivy 0.74.0, pip-audit 2.10.1, npm 11.7.0)
- security-platform: `.github/workflows/security.yml` (the import TABLE and the cleanup job), `defectdojo-import-proof.yml`, `scripts/defectdojo-import-proof.sh`, `scripts/check-defectdojo-chart.sh`, `scripts/defectdojo-live-smoke.sh`

### Secondary / Tertiary
- None. No web or doc sources were relied on, by design: pinned source only.

## Metadata

**Confidence breakdown:**
- Engine behaviour (dedup, re-parent, reimport, settings): HIGH, read in pinned source with line refs
- Cross-tool gap: HIGH, parser code plus a measured scanner run
- Chart mechanism: HIGH, rendered
- Proof design: MEDIUM, a design that has not been executed yet (async timing, P-COUNTS interaction)

**Research date:** 2026-09-25
**Valid until:** the pin changes (ADR-023). Re-verify on any DefectDojo app bump.
