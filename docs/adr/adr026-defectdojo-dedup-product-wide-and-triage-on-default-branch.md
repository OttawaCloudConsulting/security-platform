# ADR-026: DefectDojo Dedup Is Product-Wide and Triage Happens on the Default Branch

**Status:** Accepted
**Date:** 2026-09-26
**Addresses:** DDOJO-03 — deduplication rules configured so repeated findings across scans and tools
collapse rather than duplicate — and DDOJO-04 — a triage workflow documented and configured for
reviewing and dispositioning findings in DefectDojo

This record lives in this documentation repository. The public `security-platform` runbook
`kubernetes/defectdojo/TRIAGE.md`, the chart README and `values.yaml` cite it by number, so a
reader of the public repository cannot follow the link. That is the same arrangement ADR-022 to ADR-025 recorded. Every
measured value below is quoted from a Phase 28 plan summary (28-05, 28-06, 28-07, 28-08) or from a file
in that phase's `evidence/` directory, and each is attributed where it appears. The cross-tool parser
table is quoted from 28-RESEARCH, which read the pinned DefectDojo 3.3.200 source. No homelab address,
hostname, token, product name or DefectDojo instance URL appears here.

## Context

- **Dedup is off on a fresh 3.3.200 install.** `complete_initialization` loads the
  `system_settings.json` fixture with `enable_deduplication=false`. With the Phase 27 import alone,
  every branch reimport piles up findings and nothing is ever marked a duplicate (28-RESEARCH
  Pitfall 1). 28-05 measured the before state on a fresh kind install as `enable_deduplication:false`
  and `risk_acceptance_form_default_days:180`.
- **Imports are one engagement per branch, deleted on close (ADR-024).** Each repository's product
  holds `ci/<default>` plus one `ci/<pr-branch>` per open PR, reimported in place. The PR engagement
  is deleted when the PR closes. So the only source of duplicates is branch overlap, and any dedup
  scope decision has to survive that delete.
- **The operator asked for cross-tool SCA collapse (D-05).** When Trivy fs, NPM Audit v7+ and
  pip-audit report the same vulnerability in the same package, they should collapse into one finding.
  IaC (Checkov, tflint) and secrets (Semgrep, Gitleaks) stay within-tool. D-07 is the fallback if the
  pinned parsers cannot support it.
- **The System Settings API is superuser-only.** `SystemSettingsViewSet` requires `IsSuperUser`
  (28-RESEARCH Pitfall 2). The Phase 27 CI token belongs to a staff, non-superuser account by design
  (27 D-10, ADR-024), so it cannot turn dedup on.
- **ADR-024 handed dedup forward.** Its consequence "Hand-forward — Phase 28 owns deduplication" left
  `enable_deduplication` at its default and noted that `deduplication_on_engagement` is read only at
  engagement creation. ADR-024 may not be edited (`docs/adr/` is append-only per `CLAUDE.md`).

## Decision

1. **Dedup is product-wide, and delete-duplicates stays off.** Dedup scope is the whole product, which
   is the DefectDojo default. `deduplication_on_engagement` is not set, so it stays `false` on every
   `ci/*` engagement (D-01). A finding on a PR engagement that already exists on `ci/<default>` becomes
   an inactive duplicate of the default-branch finding, and the PR engagement's active list shows only
   what the PR introduces. "Delete Deduplicate Findings" and "Maximum Duplicates" stay off, the upstream
   default (D-04): reimport in place already stops a new Test per run (27 D-07), and closed PRs delete
   their engagements.
2. **D-02 is resolved by delete-time re-parenting, so D-03 was not built.** The edge case: a finding
   first appears on a PR, the PR merges, and the default-branch copy is a duplicate of the PR's
   finding when the PR engagement is deleted. In 3.3.200, `Engagement.delete()` calls
   `prepare_duplicates_for_delete()`, which re-parents each outside duplicate synchronously inside the
   DELETE: the lowest-id outside duplicate becomes the original, `duplicate=False`, with the original's
   `active`, `verified` and `is_mitigated` (28-RESEARCH Pattern 3). 28-05 and 28-07 measured it (see
   below). The operator's "the next daily reimport heals it" model was wrong in the harmless direction:
   there is no window at all. The D-03 cleanup-job fallback was therefore not built, `security.yml` did
   not change, and no v1.x tag was cut; `v1` still points at `917352c` (28-08).
3. **Cross-tool SCA collapse is not achievable in 3.3.200; D-07 applies.** DefectDojo computes
   `hash_code` as `sha256(casefold(concat(fields)))` over the configured fields, with no fuzzy matching.
   The three SCA parsers populate those fields incompatibly (28-RESEARCH § Cross-Tool Measurement,
   parser sources read at the 3.3.200 tag):

   | Parser (scan_type) | `vulnerability_ids` | `component_name` | `component_version` | Findings per |
   |---|---|---|---|---|
   | `Trivy Scan` | `[VulnerabilityID]`, e.g. `CVE-2018-18074` | `PkgName`, e.g. `requests` | `InstalledVersion` | CVE × package |
   | `NPM Audit v7+ Scan` | not set | `nodes[0]`, e.g. `node_modules/lodash` | not set | package |
   | `pip-audit Scan` | `[vuln.id]` only, e.g. `PYSEC-2018-28`; aliases ignored | `name`, e.g. `requests` | `version` | advisory × package |

   No subset of the allowed hash fields gives equal hashes for the same vulnerability across these
   parsers without also merging distinct ones: `component_name` plus `component_version` alone would
   merge 5 distinct `requests` advisories into 1. The live proof measured the gap (28-05, repeated on
   GitHub by 28-07):

   ```text
   PROOF: P-CROSSTOOL PASS 23 duplicate link(s) touch an SCA finding in ci/main; 0 cross scan types
   CROSSTOOL: scan_type='NPM Audit v7+ Scan' findings=2 with_vulnerability_ids=0 with_component_version=0 sample_components=['node_modules/lodash', 'node_modules/minimist']
   CROSSTOOL: package=requests trivy_ids=['CVE-2018-18074'] pip_audit_ids=['PYSEC-2018-28', 'PYSEC-2023-74', 'PYSEC-2026-1872', 'PYSEC-2026-1873', 'PYSEC-2026-2275'] shared=[]
   ```

   Per D-07, no normaliser was written. The shipped behaviour is within-tool dedup plus product-wide
   (cross-branch) dedup, and DDOJO-03 closes on that basis. D-06's import order (Trivy fs before npm
   and pip-audit) is unchanged; with no cross-tool collapse it no longer decides an original.
4. **Configuration has two homes, and one step is documentation only.**
   - **Chart guards (D-20).** `kubernetes/defectdojo/values.yaml` ships exactly two
     `defectdojo.extraConfigs` entries: `DD_DUPLICATE_CLUSTER_CASCADE_DELETE: "False"`, because `True`
     would make the PR-engagement DELETE delete the default-branch duplicates instead of re-parenting
     them, and `DD_DEDUPLICATION_ALGORITHM_PER_PARSER`, which restates the 3.3.200 algorithm for the 7
     imported scan types as drift defence on a version bump. No `DD_HASHCODE_FIELDS_PER_SCANNER`
     override ships. `scripts/check-defectdojo-chart.sh` asserts both, including that the algorithm
     map parses as JSON, and is at `CHECK_COUNT=22` on `origin/main` (28-08).
   - **Bootstrap script (D-10, D-22).** `scripts/defectdojo-configure.sh` does an idempotent
     read-compare-PATCH of `/api/v2/system_settings/` for five settings: `enable_deduplication=true`,
     `delete_duplicates=false`, `false_positive_history=false`,
     `retroactive_false_positive_history=false` and `risk_acceptance_form_default_days=90`. The two
     FP-history flags are set false explicitly because the API, unlike the UI, does not refuse them
     together with dedup. The operator runs it once per install; a rerun changes nothing. It follows
     the Phase 27 token idiom and ADR-025: https only, TLS verified, the token in a 0600 header file,
     never on argv.
   - **SLA untouched (D-21).** The script does not read or write `enable_finding_sla`; it stays at the
     upstream default.
   - **Hash recompute documented, not automated (D-08).** Changing hash fields changes `hash_code` for
     findings already imported. The chart README gives the upstream `manage.py dedupe` command to run
     after such a change on an existing install. Nothing runs it automatically, and no live install
     existed in this phase.
5. **Triage is on the default-branch engagement, in DefectDojo.**
   - **System of record (D-13).** DefectDojo is authoritative for triage. The GitHub Security tab
     (SARIF, CICD-02) is per-PR developer feedback and is not triaged. The two are not synced, and the
     runbook says so.
   - **Default branch only (D-14).** Triage happens on `ci/<default>` only; PR engagements are
     transient review views. The code-level reason is 28-RESEARCH Pattern 3 Caveat A: the delete-time
     re-parent copies only `active`, `verified` and `is_mitigated`, never `false_p`, `out_of_scope` or
     `risk_accepted`. A disposition set on a PR-engagement original is lost when that engagement is
     deleted, and the default-branch copy can be left inactive and un-dispositioned, which no reimport
     reactivates. A disposition on the default-branch original does cover future PRs: their copies
     arrive as inactive duplicates of it (P-SUPPRESS, below).
   - **Six dispositions (D-15).** Under Review, Verified/Active, False Positive, Risk Accepted, Out of
     Scope and Mitigated (set by reimport through `close_old_findings`). False Positive, Out of Scope
     and Risk Accepted are never reactivated by a reimport, and no reimport flag is needed:
     `process_matched_finding` routes a dispositioned finding to the special-status path before the
     mitigated check (28-RESEARCH Pattern 4). `do_not_reactivate` stays off so that a fixed issue that
     regresses reopens.
   - **Under Review is the implicit queue (D-15, D-23).** It is not the native `under_review` flag,
     which is the multi-reviewer request workflow. It is the query: on `ci/<default>`, active, not
     verified, not a duplicate, not mitigated, and none of False Positive, Out of Scope or Risk
     Accepted. Every new finding lands in it with no automation. The runbook gives the UI filter and
     the API query.
   - **Risk acceptance by procedure (D-22).** Full risk acceptance only (the per-product default);
     simple risk acceptance stays disabled. `Risk_Acceptance.expiration_date` and `decision_details`
     are nullable in 3.3.200, so DefectDojo cannot enforce either. The runbook makes an expiry date and
     a reason mandatory by procedure, and the bootstrap pre-fills the UI form's expiry at 90 days.
   - **SLA excluded (D-16).** Triage means dispositions only. SLA tracking and notifications are not
     configured by this phase; the runbook says so.
   - The runbook is `kubernetes/defectdojo/TRIAGE.md` in `security-platform` (D-17), linked from
     section 12 of `docs/adoption-guide.md` by a `blob/main` URL (D-24).
6. **The bootstrap token is a superuser token, deliberately split from the CI token.** The staff,
   non-superuser `DEFECTDOJO_API_TOKEN` of 27 D-10 and ADR-024 cannot call the System Settings API and
   is not widened. The bootstrap uses a separate superuser token that the operator holds for the
   one-time run. It is never the CI token and never a GitHub secret: no workflow uses it.

### Measured evidence

- **Local kind proof (28-05):** `evidence/28-05-local-proof.log`, attempt 3 at `security-platform`
  `13b1402`: `PROOF PASS - 127 assertions` (35 in the Phase 28 block, 92 Phase 27) and
  `ALL PASS - 13 live check(s)`. Wall-clock 281 s, of which the Phase 28 block took 68 s.
- **Bootstrap (28-05, repeated in 28-07):** run 1 printed
  `CHANGED: enable_deduplication, risk_acceptance_form_default_days`; run 2 printed
  `NO CHANGE: all 5 settings already match`. After it, `enable_deduplication` was `true`,
  `risk_acceptance_form_default_days` was `90`, and `enable_finding_sla` stayed `true`.
- **Branch dedup (P-DEDUP-BRANCH, 28-05):** the PR engagement held 155 findings, 154 of them
  duplicates; the one non-duplicate was the active delta `CVE-2020-8203` lodash 4.17.15. Dedup
  settled 7 s after the import.
- **Dispositions (P-DISPOSITION, 28-05):** after reimport 1 and again after reimport 2:
  - FP #231: `false_p=True out_of_scope=False risk_accepted=False active=False is_mitigated=True`
  - OOS #232: `false_p=False out_of_scope=True risk_accepted=False active=False is_mitigated=True`
  - RA #233: `false_p=False out_of_scope=False risk_accepted=True active=False is_mitigated=False`

  `statistics.delta.reactivated.total = 0` on both reimports, and the FP and OOS `mitigated`
  timestamps (`2026-09-26T14:28:55.922264Z`, `2026-09-26T14:28:56.086078Z`) did not change across
  them. The RA `expiration_date` was `2026-12-25T00:00:00Z`.
- **PR suppression (P-SUPPRESS, 28-05):** the PR copies #540, #541 and #542 were each
  `dup=True active=False`, pointing at #231, #232 and #233; the PR engagement held 154 findings and
  0 were active.
- **Re-parent (P-REPARENT, 28-05):** K=6. Read 1 s after the engagement DELETE returned, with no
  reimport, `ci/main` had 6 findings with `duplicate=false` and `active=true`, 0 duplicates.
- **GitHub proof (28-07):** DefectDojo Import Proof run `36261602015`, attempt 1, no rerun,
  prove-import job `108458517558` success in 7m08s: `PROOF PASS - 127 assertions`, the same 35
  Phase 28 PASS lines, and the same bootstrap, dedup, cross-tool, suppression and K=6 re-parent values
  as the local run (`evidence/28-07-proof-run.log`). The five required `security / ...` contexts
  passed; DefectDojo Import and Cleanup skipped (`evidence/28-07-pr-checks.txt`).
- **Merge (28-08):** PR #23 merged with `gh pr merge 23 --merge` as the two-parent merge commit
  `c8027e6784ec631db128f45444c9a8092db9d0a1` (parents `917352c00987023fa5ff1e6cdabc16987eb114dd`, the
  prior main, and `c77e4f4d47e820c76914ca798a88be9b610fb130`, the PR head). Read from `origin/main`:
  both D-20 guards, `CHECK_COUNT=22`, the configure script, `TRIAGE.md`, and chart `version: 0.2.0`.
  `security.yml`, both callers and `set-required-checks.sh` are byte-identical to `917352c`, and `v1`
  is unchanged at `917352c` (`evidence/28-08-post-merge.txt`).

## Consequences

**Improved:** a PR engagement's active list is what the PR introduces, not a copy of the default
branch; a merged PR's findings become default-branch originals the moment the PR engagement is
deleted; and a disposition made on `ci/<default>` survives every reimport and suppresses the same
finding on later PRs. None of it needed a `security.yml` change or a consumer action.

**Tradeoff — FP and OOS findings read as Mitigated.** A False Positive or Out of Scope finding reads
`is_mitigated=True` with its disposition flag kept. 28-06 recorded this from the moment of
disposition, before any reimport; the timestamps above are the disposition time and two reimports
left them unchanged. It is cosmetic: the disposition is kept, and nothing reactivates the finding.

**Tradeoff — legacy-hash scanners are line-sensitive.** Checkov, Gitleaks, Semgrep and the tflint
SARIF use the legacy hash (`title+cwe+line+file_path+description`). A PR that shifts lines above an
existing issue shows it as new on the PR engagement. The runbook calls this expected noise; the hash
fields were not changed.

**Tradeoff — no cross-tool collapse.** The same vulnerability reported by Trivy and pip-audit, or by
Trivy and npm audit, is two findings and is triaged twice. Closing this needs a parser change upstream
or a normaliser, and D-07 rejected the normaliser.

**Tradeoff — Trivy originals arrive Verified.** 28-05 measured Trivy Scan originals imported through
the committed body landing `verified=true`, although the body sends no `verified` field. For Trivy,
Verified is not a triage signal, and the runbook's untriaged query drops the `verified=false` filter
for it. Other parsers were not checked.

**Closes ADR-024's Phase 28 hand-forward.** Dedup is now owned and on after the bootstrap. Because
D-01 keeps `deduplication_on_engagement` at its default, the `PATCH /api/v2/engagements/{id}/` or
re-create step ADR-024 anticipated for existing `ci/*` engagements never arises. ADR-024 itself is
not edited.

**Hand-forward — Phase 29.** The live install must run `bash scripts/defectdojo-configure.sh` once
with an operator-held superuser token, after the chart is up; until then dedup is off on that install.
Phase 29 must then re-prove dedup, the dispositions and the re-parent on the live instance, not rely on
the kind proof.

## What was NOT verified

What WAS measured and must not be re-litigated: the bootstrap's change-then-no-change runs, the
branch dedup delta, the cross-tool gap, the three disposition tuples across two reimports, the PR
suppression and the delete-time re-parent, on local kind (28-05) and on GitHub (36261602015 attempt 1,
28-07); and the merged tree on `origin/main` (28-08).

1. **No live install with existing findings.** Every run used a fresh ephemeral 3.3.200 install. How
   turning dedup on behaves against an install that already holds non-deduplicated findings is
   Phase 29's to observe.
2. **The hash recompute command was not run against real data.** The D-08 `manage.py dedupe` command
   is documented from the 3.3.200 source; it excludes `duplicate=True` findings from reprocessing, and
   no measurement checked its outcome.
3. **Multi-triager permissions are deferred.** The runbook assumes one operator. Who may disposition
   on `ci/<default>`, and the native `under_review` peer-review flow, were not designed or tested.
4. **Only DefectDojo 3.3.200.** The re-parent, the special-status reimport path and the parser
   fields were read and measured at 3.3.200 only. The D-20 algorithm restatement is drift defence for
   a bump, not evidence that a later version behaves the same.
5. **Caveats B and C of 28-RESEARCH Pattern 3 were not exercised.** Re-parenting onto another open
   PR's copy, and re-parenting an already-mitigated PR original, are source-derived only.
6. **Risk-acceptance expiry was not exercised.** The 3-hourly expiration handler and its reactivation
   were not run; the proof only read the stored `expiration_date`.
