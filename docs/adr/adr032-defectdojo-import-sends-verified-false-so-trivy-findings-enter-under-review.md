# ADR-032: The DefectDojo Import Sends verified=false So Trivy Findings Enter Under Review

**Status:** Accepted
**Date:** 2026-10-05
**Addresses:** Phase 28 WR-03 (28-REVIEW, the `TRIAGE.md` Under Review query leaves out every Trivy finding),
v3.0-MILESTONE-AUDIT tech-debt item 5 (28 WR-03), and the ADR-026 tradeoff "Trivy originals arrive Verified"

This record lives in this documentation repository. The `dd-import` comment and the `"verified=false",` line in
`.github/workflows/security.yml`, the VERIFIED-FALSE check (check 22) in `scripts/check-workflow-uploads.sh` and the
VERIFIED header comment in `scripts/defectdojo-lifecycle-assert.sh` in the public `security-platform` repository cite
it by number, so a reader of the public repository cannot follow the link. That is the arrangement ADR-022 to ADR-031
recorded. Every measured value below is quoted from a Phase 29.5 plan summary (29.5-01 to 29.5-11) or from a file in
that phase's `evidence/` directory, and each is attributed where it appears. This record was written after `v1.4.0`
was tagged and `v1` was moved (29.5 D-18), so the kind proof, the live readback, the reset and the tag readback are
quoted from evidence rather than predicted.

## Context

- **The gap was measured live in Phase 29.** The Phase 29 live `ci/main` baseline
  (`main-baseline-snapshot.json`, 155 findings) held Test 3 (`trivy-fs`, 6 findings) and Test 4 (`trivy-image`,
  59 findings), all `verified=true`, and 6 other Tests with 90 findings, all `verified=false` (29.5-CONTEXT). The
  canonical `TRIAGE.md` Under Review query filters `verified=false`, so it hid 65 of 155 findings (42%), and those
  65 were exactly the Trivy findings. For Trivy, Under Review and Verified/Active could not be told apart
  (28-REVIEW WR-03). ADR-026 recorded the symptom as the tradeoff "Trivy originals arrive Verified" (28-05) and noted
  that other parsers were not checked.
- **The cause, read from source.** The DefectDojo 3.3.200 source was read at tag commit
  `395f040530891acc1ca5642785b03d51ff25c8b6` (29.5-RESEARCH Findings 1 to 5). Label: **read from source**, not a
  guess (D-03).
  - The Trivy parser maps each vulnerability's `Status` to a `verified` value. `convert_trivy_status`
    ([parser.py L80-157](https://github.com/DefectDojo/django-DefectDojo/blob/395f040530891acc1ca5642785b03d51ff25c8b6/dojo/tools/trivy/parser.py#L80-L157))
    maps `affected`, `fixed`, `will_not_fix`, `fix_deferred`, `end_of_life` and `not_affected` to
    `"verified": True`. It is applied per vulnerability at
    [parser.py L353](https://github.com/DefectDojo/django-DefectDojo/blob/395f040530891acc1ca5642785b03d51ff25c8b6/dojo/tools/trivy/parser.py#L353)
    and spread into the `Finding(...)` at
    [parser.py L384](https://github.com/DefectDojo/django-DefectDojo/blob/395f040530891acc1ca5642785b03d51ff25c8b6/dojo/tools/trivy/parser.py#L384).
  - When the request omits `verified`, the serializer passes `verified=None` to the importer
    ([serializers.py L639-642](https://github.com/DefectDojo/django-DefectDojo/blob/395f040530891acc1ca5642785b03d51ff25c8b6/dojo/api_v2/serializers.py#L639-L642)),
    so the importer leaves the parser's value in place. The other parsers set no value and fall back to the model
    default `verified=False`
    ([models.py L225](https://github.com/DefectDojo/django-DefectDojo/blob/395f040530891acc1ca5642785b03d51ff25c8b6/dojo/finding/models.py#L225)).
    This is not an import or reimport default.
  - An explicit value overrides the parser. `ReImportScanSerializer.process_scan`
    ([serializers.py L858-879](https://github.com/DefectDojo/django-DefectDojo/blob/395f040530891acc1ca5642785b03d51ff25c8b6/dojo/api_v2/serializers.py#L858-L879))
    uses the DefaultImporter for the first call on a Test and the DefaultReImporter after that. Both write
    `self.verified` onto a new finding when it is not `None`
    ([default_importer.py L248-250](https://github.com/DefectDojo/django-DefectDojo/blob/395f040530891acc1ca5642785b03d51ff25c8b6/dojo/importers/default_importer.py#L248-L250),
    [default_reimporter.py L1292-1294](https://github.com/DefectDojo/django-DefectDojo/blob/395f040530891acc1ca5642785b03d51ff25c8b6/dojo/importers/default_reimporter.py#L1292-L1294)).
  - A matched finding that is active and still reported keeps its `verified` value
    ([default_reimporter.py L1250-1252](https://github.com/DefectDojo/django-DefectDojo/blob/395f040530891acc1ca5642785b03d51ff25c8b6/dojo/importers/default_reimporter.py#L1250-L1252)).
    A mitigated match that is reactivated takes `self.verified`
    ([default_reimporter.py L1155-1164](https://github.com/DefectDojo/django-DefectDojo/blob/395f040530891acc1ca5642785b03d51ff25c8b6/dojo/importers/default_reimporter.py#L1155-L1164)).
    Duplicates are always set `verified=False`
    ([deduplication.py L131](https://github.com/DefectDojo/django-DefectDojo/blob/395f040530891acc1ca5642785b03d51ff25c8b6/dojo/finding/deduplication.py#L131),
    [L178-182](https://github.com/DefectDojo/django-DefectDojo/blob/395f040530891acc1ca5642785b03d51ff25c8b6/dojo/finding/deduplication.py#L178-L182)).
  - From these, the source predicted three things: the fix would not reset findings imported before it, a
    triager's Verified on an active finding would survive, and a reactivated finding would return unverified. The
    kind proof measured all three (see Measured evidence).
- **ADR-026 may not be edited.** `docs/adr/` is append-only per `CLAUDE.md`. The supersession below is stated in
  this record's prose.

## Decision

1. **The `dd-import` fields list sends `verified=false` on every reimport-scan call (D-01, D-02).** The line
   `"verified=false",` sits in the `fields` list of the `dd-import` body in `security.yml`, between
   `"close_old_findings=true",` and `"branch_tag=" + branch[:150],`. `dd-import` calls only
   `/api/v2/reimport-scan/` with `auto_create_context=true`, so the one line covers the first run and every later
   run, for all 8 reports. It has no `scan_type` or parser condition (29.5-01, `security-platform` commit
   `d2db557`, merged through PR #35).
   - **Why.** "Untriaged" now means the same thing for every parser, and Verified means one thing: a triager
     confirmed the finding is real. The `TRIAGE.md` Under Review query and its six states stay as written.
   - **Rejected alternatives.** Dropping `verified` from the query loses the "confirmed real" state. A `triaged`
     tag needs a manual step on every finding (D-01). WR-03 listed both, and also listed the import change as a
     follow-up; this record takes the import change.
2. **A static gate holds the field (D-14).** `scripts/check-workflow-uploads.sh` gained VERIFIED-FALSE (check 22).
   It requires `"verified=false",` exactly once in the `dd-import` step, `verified=` exactly once overall, and the
   field inside the `fields = [` list before that list's own closing `]`. On the unfixed workflow it failed RED with
   3 `FAIL: VERIFIED-FALSE:` lines. Three scratch negatives each exit 1: the line deleted (3 failures), the line
   changed to `verified=true` (2), and the field moved into a comment after `]` (1). GREEN is
   `PASS - 22 checks, 0 failures` (29.5-01, `evidence/29.5-01-verified-false-gate.txt`; commit `c796165`).
3. **A kind proof, P-VERIFIED, proves the claim (D-10, D-11).** `scripts/defectdojo-import-proof.sh` gained the
   `prove_verified` group with six labels: P-VERIFIED-BODY, P-VERIFIED-FALSE (all 8 reports twice with the
   committed body, plus an old-body negative control with only the `verified=false` line removed),
   P-VERIFIED-NEWREIMPORT (D-04), P-VERIFIED-RESET (D-05, D-11), P-VERIFIED-TRIAGER (D-06) and
   P-VERIFIED-REACTIVATE (D-07) (29.5-03, 29.5-04; commits `e57b621` and `d2e813d`).
4. **The lifecycle-assert text follows the behaviour (D-13).** In `scripts/defectdojo-lifecycle-assert.sh` the
   "TRIVY CAVEAT" header comment became "VERIFIED (TRIAGE.md, ADR-032)", and only the parenthesised note in the
   D11-STEP2-UNTRIAGED-EQ-FIXTURE failure text changed. The verbatim Under Review query and the `.verified != false`
   check are unchanged, and `--help` output is byte-identical (29.5-01, commit `be0441e`).
5. **The one-time reset was needed, and it ran (D-05).** The fix does not reset findings imported before it: 65 of
   65 triage-open Trivy findings on `ci/main` still read `verified=true` after the first new-body reimport. The
   operator approved the 65 ids and chose the executor as the runner. The committed recipe in
   `29.5-reset-recipe.md` PATCHed each to `verified=false`: 65 HTTP 200 responses, 0 left `verified=true`, no
   non-Trivy finding changed (29.5-07, 29.5-08). `TRIAGE.md` now carries the recipe, in the section "One-time reset
   after upgrading to v1.4.0" (PR #36).
6. **Release: `v1.4.0`, with `v1` moved (D-15, D-16).** Consumers see a change in triage semantics, so it is a minor
   release, following the `v1.2.0` and `v1.3.0` precedent. PR A (#35, the field, the gate, the proof and the
   lifecycle text) merged as `a53f6fb`. PR B (#36, the `TRIAGE.md` text) merged as `6c0d531`. `v1.4.0` is an
   annotated tag on `6c0d531`, and the lightweight `v1` moved there from `aa48081` (ADR-018). The operator replied
   "Approve" at the release checkpoint. No GitHub Release object was created (`evidence/29.5-11-tags.json`,
   `github_release_created: false`).

**Supersession.** ADR-026 records: "**Tradeoff — Trivy originals arrive Verified.** 28-05 measured Trivy Scan
originals imported through the committed body landing `verified=true`, although the body sends no `verified` field.
For Trivy, Verified is not a triage signal, and the runbook's untriaged query drops the `verified=false` filter for
it. Other parsers were not checked." This record supersedes that tradeoff, in prose, from `v1.4.0` on, and it closes
28-REVIEW WR-03. It also answers the open point "Other parsers were not checked": in kind, all 91 non-Trivy findings
read `verified=false` under the old body. ADR-026's statement remains an accurate record of `v1.3.0` and earlier.
This record changes nothing in ADR-026; the file is byte-unchanged against docs commit `eb21269`.

## Measured evidence

Each row is labelled **kind** (the DefectDojo Import Proof in a kind cluster, DefectDojo 3.3.200) or **live** (the
homelab `ci/main` engagement), per D-09. The kind and live Trivy counts differ because they are different data sets:
kind imports the CI reports of PR A (66 Trivy, 157 findings in 8 Tests), and live `ci/main` holds 65 triage-open
Trivy findings (5 `trivy-fs`, 60 `trivy-image`).

| Measurement | Where | Result | Source |
|---|---|---|---|
| VERIFIED-FALSE gate | static | RED 3 `FAIL: VERIFIED-FALSE:` lines; 3 of 3 scratch negatives exit 1 (3, 2 and 1 failures); GREEN `PASS - 22 checks, 0 failures` | 29.5-01, `evidence/29.5-01-verified-false-gate.txt` |
| Kind proof on PR A (#35, head `d2e813d`) | kind | DefectDojo Import Proof run 37248805435: `PROOF PASS - 189 assertions`, 0 FAIL lines; P-VERIFIED-BODY 3, P-VERIFIED-FALSE 7, P-VERIFIED-NEWREIMPORT 2, P-VERIFIED-RESET 2, P-VERIFIED-TRIAGER 2, P-VERIFIED-REACTIVATE 1 PASS | 29.5-05, `evidence/29.5-05-pr-a-run.txt`, `evidence/29.5-06-kind-results.json` |
| P-VERIFIED-FALSE positive calls | kind | both calls: 157 findings in 8 Tests all `verified=false` (checkov 14, gitleaks 18, npm-audit-1 2, pip-audit-1 47, semgrep 7, tflint 3, trivy-fs 6, trivy-image 60) | `evidence/29.5-06-kind-results.json` d04 |
| P-VERIFIED-FALSE negative control (old body) | kind | 66 of 66 non-duplicate Trivy findings `verified=true` (28-05 and the Phase 29 split reproduced); 91 of 91 non-Trivy findings `verified=false` | `evidence/29.5-06-kind-results.json` d04 |
| P-VERIFIED-NEWREIMPORT (D-04) | kind | a reimport of the full `trivy-fs.json` created exactly 1 new finding (#1252, CVE-2020-8203 lodash 4.17.15, Status `fixed`, which the parser maps to `verified` True); stored `verified=False`, `duplicate=False` | `evidence/29.5-06-kind-results.json` d04 |
| P-VERIFIED-RESET (D-05, D-11) | kind | `still_true=66 of 66` pre-fix Trivy ids after the committed-body reimport, `now_false=0`, equal to the source prediction; after a PATCH to false, all 66 stayed `verified=false` across a further reimport | `evidence/29.5-06-kind-results.json` d05_reset |
| P-VERIFIED-TRIAGER (D-06) | kind | (a) semgrep finding 1090 PATCHed `verified=true` kept `verified=true` after the reimport; (b) trivy-fs finding 1247 likewise; both active | `evidence/29.5-06-kind-results.json` d06_triager |
| P-VERIFIED-REACTIVATE (D-07) | kind | X=1253 (gitleaks): step 3 `verified=true` active; step 4 mitigated, `verified=true`; step 5 reactivated `active=true`, `is_mitigated=false`, `verified=false`, equal to the source prediction | `evidence/29.5-06-kind-results.json` d07_reactivate |
| D-07 ruling | operator | reply verbatim `accept`; `l36_l40_sentence_allowed: true` | `evidence/29.5-06-rulings.json` |
| PR A merge | live | #35 merged untagged as `a53f6fb773a782411a9d32ea5457d8d2a31ba465` (second parent `d2e813d`, the approved head) | 29.5-07, `evidence/29.5-07-merge.txt` |
| D-12 live readback after the upgrade | live | dispatch 37251249025 on `a53f6fb`: `before_open_trivy` 65, all `verified=true`; `still_true` 65, `now_false` 0, `no_longer_open` 0; `non_trivy_verified_changed` 0; verdict PASS; `reset_needed` true | `evidence/29.5-07-d12-fix.json` |
| New Trivy findings live | live | `new_trivy` 0 in that reimport, so no live finding tested the new-finding path. **The claim that new Trivy findings arrive `verified=false` rests on kind evidence only** (P-VERIFIED-FALSE, P-VERIFIED-NEWREIMPORT) | `evidence/29.5-07-d12-fix.json` |
| D-05 one-time reset | live | operator reply verbatim `approved - executor runs it`; 65 approved ids (trivy-fs 23-27, trivy-image 1156-1215); 65 of 65 PATCH HTTP 200; `reset_count` 65, `after_open_trivy_true` 0, `non_trivy_verified_changed` 0, `out_of_scope_trivy_changed` 0; verdict PASS | 29.5-08, `evidence/29.5-08-d05-reset.json`, `evidence/29.5-08-reset-diff.json` |
| Kind proof on PR B (#36, head `9456cbb`) | kind | run 37256101450 attempt 1 failed at KIND-INSTALL before any P-VERIFIED assertion ran (the ingress-nginx admission webhook was not yet serving about 1 s after the rollout PASS); operator reply verbatim `Rerun`; attempt 2 `PROOF PASS - 189 assertions`, all P-VERIFIED lines PASS | 29.5-09, `evidence/29.5-09-pr-b.txt` |
| PR B merge | live | #36 merged as `6c0d5319b1c328f135b47acd47e1a5e92ae2b10c` at 2026-10-05T03:30:48Z; merge tree identical to `9456cbb`; `TRIAGE.md` only, no workflow file changed | 29.5-10, `evidence/29.5-10-merge.txt` |
| D-16.1 workflow surface | static | `v1.3.0..6c0d531` in `security.yml`: 2 hunks, +8/-0 (a `dd-import` comment and `"verified=false",`); surface diff PASS with only the `dd-import` `run:` body changed; the scratch negative FAILs; `check-workflow-uploads.sh` at `6c0d531` `PASS - 22 checks, 0 failures` | `evidence/29.5-11-impact-check.json` d16_1 |
| D-16.2 tag equality | live | `v1^{}` = `v1.4.0^{}` = `6c0d531`, read from the GitHub API and locally; verdict PASS | `evidence/29.5-11-tags.json` d16_2 |
| D-16.3 consumers without DefectDojo | static | the `jobs.defectdojo-import` `if:` is byte-equal at `v1.3.0` and `6c0d531`, so a consumer without `vars.DEFECTDOJO_URL` never runs the import | `evidence/29.5-11-impact-check.json` d16_3 |
| D-16.4 `@v1` callers | live | 61 org repositories scanned (10 with a workflows directory, 20 workflow files), 0 strict `uses:` callers; 2 broad matches, both comments in `security-platform`'s own workflows. The operator's reply `Approve` approved the release but **did not confirm** that there are no callers outside the org (`confirmation_given: false`) | `evidence/29.5-11-impact-check.json` d16_4, `evidence/29.5-11-tags.json` |
| Dependabot hazard | live | #30 and #31 (touch `security.yml`, base `30afdb9`) held unmerged; `git log a53f6fb..6c0d531 -- security.yml` empty | `evidence/29.5-11-impact-check.json` dependabot |
| Release | live | `v1.4.0` annotated tag object `07bac542cdacdc754b19ff377ec36ba5cbf895d7` dereferences to `6c0d5319b1c328f135b47acd47e1a5e92ae2b10c`, tagger date 2026-10-05T03:53:32Z; tag message byte-identical to `evidence/29.5-11-tag-message.txt` (2508 bytes); `v1` moved from `aa48081681ee1e578c50d6a0d9e5ead6ff6afc67` to `6c0d531`; `v1.3.0` and every other tag unchanged | `evidence/29.5-11-tags.json` |

Rollback, not run: `git tag -f v1 aa48081681ee1e578c50d6a0d9e5ead6ff6afc67` and a forced push of `refs/tags/v1` in
`security-platform`. `v1.4.0` stays, and `v1.3.0` remains the immutable escape hatch (`evidence/29.5-11-tags.json`).

## Consequences

**Improved:** Trivy findings enter Under Review. The `TRIAGE.md` Under Review query now returns untriaged findings
from every parser, and Verified means a triager confirmed the finding is real. The state model of 28-REVIEW WR-03
holds for the largest finding source.

**Upgrade note (D-17, the third of three places; the others are the `v1.4.0` annotated tag message and
`docs/adoption-guide.md` §12):**

- Trivy findings now enter Under Review.
- Findings imported before `v1.4.0` keep `verified=true`: a reimport does not reset Verified on a finding that is
  still active. Run the one-time reset in `TRIAGE.md`, section "One-time reset after upgrading to v1.4.0". Measured
  live on `ci/main`: 65 findings reset, 0 left `verified=true`, no non-Trivy finding changed.
- A Verified set by a triager on an active finding is kept by reimport.
- A finding that is fixed and later comes back returns unverified, so it re-enters Under Review even if it was
  Verified before it was fixed.
- Repositories that do not enable the DefectDojo import see no change: the import job still runs only when
  `vars.DEFECTDOJO_URL` is set.
- Mode A (copy-paste) adopters change only when they re-copy the workflow; `@v1.3.0` and earlier pins are unchanged.

**Tradeoff — a reopened finding returns unverified.** With `verified=false` on every call, the reactivation path
(default_reimporter.py L1155-1164) writes `verified=false` onto a mitigated finding that comes back. Measured in kind:
finding 1253 (gitleaks) read `verified=true` while active, still `verified=true` once mitigated, and `active=true`,
`is_mitigated=false`, `verified=false` after it was reported again (`evidence/29.5-06-kind-results.json`
d07_reactivate). Before `v1.4.0` the same path left `verified=true`. The operator accepted this at the D-07
checkpoint (`evidence/29.5-06-rulings.json`, reply `accept`): a regression re-entering Under Review is the intended
reopen behaviour, and `TRIAGE.md` states it in its Mitigated row. A side effect, not measured: mitigated Trivy
findings that still carry a pre-fix `verified=true` lose it if they ever reappear, so they stayed out of the D-05
reset scope.

**Unchanged:** the dedup hash fields; the `TRIAGE.md` Under Review query and its six states; a Verified set by a
triager on an active finding that the next report still contains (measured in kind, P-VERIFIED-TRIAGER); the
`workflow_call` inputs and secrets, job names, SARIF categories, artifact names and `uses:` pins (D-16.1); consumers
that do not enable the DefectDojo import (D-16.3); and every consumer of the scan output other than DefectDojo,
including GitHub code scanning.

## What was NOT verified

What WAS measured and must not be re-litigated: the VERIFIED-FALSE RED and GREEN runs (29.5-01), the P-VERIFIED kind
proof with its old-body negative control on PR A and PR B (29.5-05, 29.5-09), the live D-12 readback (29.5-07), the
live D-05 reset (29.5-08), and the tag readback (29.5-11).

1. **Callers outside visible repositories.** The impact check enumerated only OttawaCloudConsulting default branches
   visible to the token. Callers in personal accounts, other organisations, private repositories outside the org or
   on non-default branches were not enumerated. Unlike `v1.3.0` (ADR-031), the operator did **not** confirm that
   there are none: the reply "Approve" approved the release only (`evidence/29.5-11-tags.json`,
   `d16_4_external_callers.confirmation_given: false`). Such a caller on `@v1` received this change with the `v1`
   move.
2. **The live new-finding path.** The live reimport after the upgrade brought 0 new Trivy findings, so the claim
   that new Trivy findings arrive `verified=false` rests on the kind proof (P-VERIFIED-FALSE,
   P-VERIFIED-NEWREIMPORT), not on a live finding.
3. **The reactivation path live.** The reopened-finding behaviour is measured in kind only; no live finding was
   fixed and reported again in this phase.
4. **DefectDojo versions other than 3.3.200.** The cause and the override behaviour were read from the 3.3.200
   source and measured on 3.3.200. On any DefectDojo chart bump, re-read the Trivy parser status map and the
   reimporter's `verified` handling (`default_reimporter.py` L1155-1164, L1250-1252, L1292-1294) before relying on
   this record.
5. **Mode A copies.** No consumer repository that copies `security.yml` was re-copied or measured.
6. **A cron-fired post-upgrade import.** The post-merge `ci/main` import was the operator-approved
   `workflow_dispatch` run 37251249025 of Scheduled Security; no scheduled run was observed in the window.

Follow-up, not part of this decision: the kind proof's KIND-INGRESS-NGINX step reports rollout PASS before the
ingress-nginx admission webhook is serving, which caused PR B's attempt-1 KIND-INSTALL failure. The step should wait
for the controller-admission Service endpoints, or retry a dry-run Ingress apply, before KIND-INSTALL (29.5-09).
