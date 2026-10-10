# gsd-sdk Tooling Defect Ledger

This is the single consolidated record of `gsd-sdk` defects observed in this project's `.planning/` workflow. It collects the defects that were scattered across closed-phase `deferred-items.md` files, `STATE.md` decisions, `PROJECT.md` and the milestone audits. It lives at the top of `.planning/` so that it survives milestone archiving, and future phases append to it. It records tool behaviour only; product defects are tracked elsewhere.

**Version under test:** gsd-sdk v1.42.3 (get-shit-done-cc 1.42.3)

**Re-tested:** 2026-10-10 (UTC run `2026-10-10T00:24:15Z`, Phase 29.7, plan 03; harness HEAD `4dd3cb5`, fixture `dbeabd7`)

**Re-test inputs:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-03-status.md` (per-defect status table) and `evidence/29.7-ledger-L01.txt` .. `L16.txt` (literal commands, exit codes, output and readbacks). Every Status and every Actual below is copied from those files. The Expected text comes from the Phase 29.7 research (`29.7-RESEARCH.md`, "Ledger Inventory").

**Rules:**

- (a) **This ledger is append-only.** A later re-test on a newer version appends a dated `**Re-test (vX.Y.Z, YYYY-MM-DD):**` line under the entry, with its own status and evidence path. Earlier results are never overwritten or deleted. New defects are appended as the next `GSD-SDK-NNN`.
- (b) **Mutating handlers are re-tested only in a scratch copy.** Run them in a fresh `mktemp -d` copy named `.planning`, outside any git repo, with `--project-dir <scratch-root>` and `env -u GSD_WORKSTREAM`. Never run them against the real `.planning/`. The harness is `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/29.7-ledger-retest.sh` (run with `bash`). Read-only handlers (`frontmatter.get`, `verify.key-links`, `verify.artifacts`, `summary-extract`) may run against the real repo.
- (c) **No upstream issues are filed from this ledger without explicit operator opt-in** (Phase 29.7 D-13). Each entry carries a paste-ready repro block so that filing, if the operator opts in, takes one copy.
- (d) **The source files cited below are records and stay unmodified.** This ledger cites them; it does not replace them.

**Status values:** REPRODUCES = the defect still occurs as originally recorded. FIXED = it no longer occurs. CHANGED = it occurs differently. NEW = first recorded in Phase 29.7 research (2026-10-08) and reproduced in the plan 03 re-test.

**Common observation (all entries):** on v1.42.3 every error result exits 0. The error is visible only in the JSON body, so a caller cannot detect failure from the exit code alone.

**Paste-ready blocks:** each block is the harness's 4-line summary copied literally from the evidence file. The harness flattens the output to one line, squeezes runs of spaces and cuts at 400 characters, and it replaces the scratch path with `<scratch-root>`. For the mutating handlers the defect is often visible only in a file readback, not in the JSON; the entry's `**Actual**` field quotes that readback.

## Summary

| ID | Handler | Defect | Status | Legacy ID |
|----|---------|--------|--------|-----------|
| GSD-SDK-001 | `frontmatter.get` | `--field` read as the field name; the positional form nests the result | REPRODUCES | D-29.1-A / L-01 |
| GSD-SDK-002 | `verify.key-links` | False negatives on double-escaped patterns | REPRODUCES | D-29.1-B / L-02 |
| GSD-SDK-003 | `verify.key-links` | "Source file not found" for branch sources | REPRODUCES | D-29.1-C / L-03 |
| GSD-SDK-004 | `verify.artifacts` | `min_lines` counts one more line than `wc -l` | REPRODUCES | D-29.1-D / L-04 |
| GSD-SDK-005 | `verify.artifacts` | Errors instead of reporting 0/0 when a plan has no artifacts | REPRODUCES | D-29.1-E / L-05 |
| GSD-SDK-006 | `state.record-metric` | Rejects the documented positional form | REPRODUCES | Phase 14 item 1, D-19-D, Phase 23 item 7 / L-06 |
| GSD-SDK-007 | `state.record-metric` | The metrics row lands under `## Deferred Items` | REPRODUCES | Phase 14 "wrong table", re-check item 5 / L-07 |
| GSD-SDK-008 | `state.add-decision` | Rejects the positional form | REPRODUCES | Phase 14 item 2, D-19-D, Phase 23 item 7 / L-08 |
| GSD-SDK-009 | `state.add-decision` | Writes `[Phase ?]` without `--phase` | REPRODUCES | Phase 14 item 2, Phase 24 item 2 / L-09 |
| GSD-SDK-010 | `state.record-session` | Positional form drops Stopped At yet reports `recorded: true` | REPRODUCES | D-19-D, Phase 24 item 1 / L-10 |
| GSD-SDK-011 | all STATE mutators | Rewrite frontmatter `status`/`progress` without reporting it (flag-form `record-session` included) | REPRODUCES | Phase 14 item 3, STATE 24-10 / L-11 |
| GSD-SDK-012 | `state.update-progress` | No-ops, yet still rewrites the frontmatter | REPRODUCES | Phase 14 item 4, Phase 23 item 6, Phase 24 item 3 / L-12 |
| GSD-SDK-013 | `roadmap.update-plan-progress`, `phase.complete` | Do not tick the milestone checklist line | REPRODUCES | Phase 23 item 8 / L-13 |
| GSD-SDK-014 | `roadmap.update-plan-progress`, `phase.complete` | Re-stamp the completion date of an already-complete row | NEW | L-14 |
| GSD-SDK-015 | `phase.complete` | `**Plans:**` regex prefix-matches decimal phases | NEW | L-15 |
| GSD-SDK-016 | frontmatter parser (`frontmatter.get`, `summary-extract`) | Keeps YAML trailing comments inside the value | NEW | L-16 |

Totals (v1.42.3, 2026-10-10): 13 REPRODUCES, 3 NEW, 0 FIXED, 0 CHANGED.

## GSD-SDK-001 — `frontmatter.get --field` reads `--field` as the field name; the positional form nests the result (legacy: D-29.1-A / L-01)

**Source:** `.planning/phases/29.1-close-gap-nexus-01-nexus-03-retroactive-verification-md-for-/deferred-items.md:12` (D-29.1-A); `.planning/v3.0-MILESTONE-AUDIT.md:71` (frontmatter, phase 29.1 item).

**Status:** REPRODUCES

**Expected:** the verify workflow's form `frontmatter.get <plan> --field must_haves` returns the plan's `must_haves` block, so `.truths` can be counted directly. Research recorded the defect as `{"error":"Field not found","field":"--field"}`, with the positional form nesting the value under `must_haves`.

**Command:** `gsd-sdk query frontmatter.get .planning/phases/23-nexus-generic-chart/23-01-PLAN.md --field must_haves` (read-only, real repo), then the positional form `gsd-sdk query frontmatter.get .planning/phases/23-nexus-generic-chart/23-01-PLAN.md must_haves`.

**Actual (v1.42.3, 2026-10-10):** `{"error": "Field not found", "field": "--field"}` (exit 0). Positional form: top-level keys `["must_haves"]`, `.truths | length` = `0`, `.must_haves.truths | length` = `4`.

**Workaround:** use the positional form and read through the extra level (`.must_haves.truths`), or parse the frontmatter with `yq --front-matter=extract '.must_haves.truths | length' <plan>` (returns `4` for 23-01, checked 2026-10-09 with yq v4.54.1).

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L01.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query frontmatter.get .planning/phases/23-nexus-generic-chart/23-01-PLAN.md --field must_haves
Expected: {"error":"Field not found","field":"--field"}; the positional form nests the value under must_haves (.truths length 0, .must_haves.truths length 4)
Actual:   { "error": "Field not found", "field": "--field" }
```

## GSD-SDK-002 — `verify.key-links` false negatives on double-escaped patterns (legacy: D-29.1-B / L-02)

**Source:** `.planning/phases/29.1-close-gap-nexus-01-nexus-03-retroactive-verification-md-for-/deferred-items.md:28` (D-29.1-B); `.planning/v3.0-MILESTONE-AUDIT.md:72`.

**Status:** REPRODUCES

**Expected:** a key link whose `pattern` is written with YAML-escaped regex (for example `provision\\.sh`) is matched against the source or target file. Research recorded false negatives: 23-02 `1/2`, 23-03 `1/2`, 23-07 `0/1`, each with "Pattern ... not found".

**Command:** `gsd-sdk query verify.key-links <plan>` for `.planning/phases/23-nexus-generic-chart/23-02-PLAN.md`, `23-03-PLAN.md` and `23-07-PLAN.md` (read-only, real repo).

**Actual (v1.42.3, 2026-10-10):** 23-02 `"verified": 1, "total": 2`, `Pattern "kubernetes/nexus/files/provision\\\\.sh" not found in source or target`; 23-03 `1/2`, `Pattern "version:\\\\s*5\\\\.26\\\\.0" not found`; 23-07 `0/1`, `Pattern "adr020-nexus-chart-base-and-eula-opt-in\\\\.md" not found`. All exit 0. The paste-ready block below shows only 23-02, and its `Actual:` line is cut at 400 characters by the harness (it ends mid-path); the full output for all three plans is in the body of the evidence file.

**Workaround:** verify the failing links by hand with `grep -E` on the single-escaped pattern against the cited file, and record the result.

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L02.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query verify.key-links .planning/phases/23-nexus-generic-chart/23-02-PLAN.md
Expected: 23-02 1/2, 23-03 1/2, 23-07 0/1, each failing link "Pattern ... not found in source or target" on a double-escaped pattern (e.g. provision\\.sh)
Actual:   { "all_verified": false, "verified": 1, "total": 2, "links": [ { "from": "repos/security-platform/scripts/nexus-live-smoke.sh", "to": "kubernetes/nexus/files/provision.sh", "via": "invokes the script the Job runs, not a copy of it", "verified": false, "detail": "Pattern \"kubernetes/nexus/files/provision\\\\.sh\" not found in source or target" }, { "from": "repos/security-platform/scripts/nexus-li
```

## GSD-SDK-003 — `verify.key-links` reports "Source file not found" for branch sources (legacy: D-29.1-C / L-03)

**Source:** `.planning/phases/29.1-close-gap-nexus-01-nexus-03-retroactive-verification-md-for-/deferred-items.md:44` (D-29.1-C); `.planning/v3.0-MILESTONE-AUDIT.md:73`.

**Status:** REPRODUCES

**Expected:** a key link whose `from` is a git branch (branch-to-branch, for example a feature branch merged into `main`) is either checked as a ref or reported as not checkable. Research recorded `0/1`, "Source file not found".

**Command:** `gsd-sdk query verify.key-links .planning/phases/23-nexus-generic-chart/23-08-PLAN.md` (read-only, real repo).

**Actual (v1.42.3, 2026-10-10):** `"verified": 0, "total": 1`, `"from": "feature/phase-23-nexus-generic-chart"`, `"detail": "Source file not found"` (exit 0).

**Workaround:** verify branch-to-branch links by hand (for example `git ls-tree origin/main` or the merged PR record) and record that evidence instead of the tool verdict.

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L03.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query verify.key-links .planning/phases/23-nexus-generic-chart/23-08-PLAN.md
Expected: 0/1, "Source file not found" for the branch source feature/phase-23-nexus-generic-chart
Actual:   { "all_verified": false, "verified": 0, "total": 1, "links": [ { "from": "feature/phase-23-nexus-generic-chart", "to": "OttawaCloudConsulting/security-platform main", "via": "pull request merged after explicit operator approval", "verified": false, "detail": "Source file not found" } ] }
```

## GSD-SDK-004 — `verify.artifacts` `min_lines` counts one more line than `wc -l` (legacy: D-29.1-D / L-04)

**Source:** `.planning/phases/29.1-close-gap-nexus-01-nexus-03-retroactive-verification-md-for-/deferred-items.md:60` (D-29.1-D); `.planning/v3.0-MILESTONE-AUDIT.md:74`.

**Status:** REPRODUCES

**Expected:** the `min_lines` line count agrees with `wc -l`. Research recorded `2/3`, "Only 49 lines, need 60", while `wc -l` reports 48 for the same file.

**Command:** `gsd-sdk query verify.artifacts .planning/phases/23-nexus-generic-chart/23-07-PLAN.md` (read-only, real repo), plus `wc -l docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md`.

**Actual (v1.42.3, 2026-10-10):** `"passed": 2, "total": 3`, `"Only 49 lines, need 60"` on `docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md`; `wc -l` = `48` (exit 0).

**Workaround:** measure with `wc -l` and judge the `min_lines` threshold by hand. The tool's count is one higher than `wc -l` on this file, so a borderline pass by the tool can be a fail by `wc -l`.

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L04.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query verify.artifacts .planning/phases/23-nexus-generic-chart/23-07-PLAN.md
Expected: 2/3, "Only 49 lines, need 60" on ADR-020 while wc -l reports 48
Actual:   { "all_passed": false, "passed": 2, "total": 3, "artifacts": [ { "path": "docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md", "exists": true, "issues": [ "Only 49 lines, need 60" ], "passed": false }, { "path": "docs/adr/README.md", "exists": true, "issues": [], "passed": true }, { "path": "CLAUDE.md", "exists": true, "issues": [], "passed": true } ] }
```

## GSD-SDK-005 — `verify.artifacts` errors instead of reporting 0/0 when a plan has no artifacts (legacy: D-29.1-E / L-05)

**Source:** `.planning/phases/29.1-close-gap-nexus-01-nexus-03-retroactive-verification-md-for-/deferred-items.md:76` (D-29.1-E); `.planning/v3.0-MILESTONE-AUDIT.md:75`.

**Status:** REPRODUCES

**Expected:** a plan with no file artifacts reports `0/0` (nothing to check). Research recorded `{"error":"No must_haves.artifacts found in frontmatter",...}` for both 23-06 and 23-08.

**Command:** `gsd-sdk query verify.artifacts .planning/phases/23-nexus-generic-chart/23-06-PLAN.md` and the same for `23-08-PLAN.md` (read-only, real repo).

**Actual (v1.42.3, 2026-10-10):** both plans `{"error": "No must_haves.artifacts found in frontmatter", "path": "...23-0N-PLAN.md"}` (exit 0).

**Workaround:** treat this error as `0/0` for plans that declare no artifacts, after confirming the plan's frontmatter has no `must_haves.artifacts` key.

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L05.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query verify.artifacts .planning/phases/23-nexus-generic-chart/23-06-PLAN.md
Expected: {"error":"No must_haves.artifacts found in frontmatter",...} for both 23-06 and 23-08
Actual:   { "error": "No must_haves.artifacts found in frontmatter", "path": ".planning/phases/23-nexus-generic-chart/23-06-PLAN.md" }
```

## GSD-SDK-006 — `state.record-metric` rejects the documented positional form (legacy: Phase 14 item 1 / D-19-D / Phase 23 item 7 / L-06)

**Source:** `.planning/milestones/v2.0-phases/14-workflow-foundation-and-action-pinning/deferred-items.md:10` (item 1) and `:51` (re-check row 1); `.planning/milestones/v2.0-phases/19-pipeline-validation-via-branch-target-prs/deferred-items.md:59` (D-19-D) and `:74`; `.planning/phases/23-nexus-generic-chart/deferred-items.md:86` (item 7); `.planning/STATE.md:240` (24-10 handler entry, which records the positional rejection); `.planning/PROJECT.md:130` (v2.0 tech-debt bullet); `.planning/milestones/v2.0-MILESTONE-AUDIT.md:33`.

**Status:** REPRODUCES

**Expected:** the positional form documented in the executor protocol (`state.record-metric <phase> <plan> <duration> <tasks> <files>`) records a metric. Research recorded `{"error":"phase, plan, and duration required"}` for the positional form, with the flag form returning `recorded: true`.

**Command:** `gsd-sdk query state.record-metric 29.7 01 5min 2 1 --project-dir <scratch-root>` (scratch copy), then the flag form `gsd-sdk query state.record-metric --phase 29.7 --plan 01 --duration 5min --tasks 2 --files 1 --project-dir <scratch-root>` in a second fresh copy.

**Actual (v1.42.3, 2026-10-10):** positional `{"error": "phase, plan, and duration required"}` (exit 0; scratch STATE unchanged). Flag form `{"recorded": true, "phase": "29.7", "plan": "01", "duration": "5min"}`.

**Workaround:** use the flag form `--phase --plan --duration --tasks --files`. In this repo the metrics row is written by hand instead (Phase 29.7 D-02), because of GSD-SDK-007 and GSD-SDK-011.

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L06.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query state.record-metric 29.7 01 5min 2 1 --project-dir <scratch-root>
Expected: positional: {"error":"phase, plan, and duration required"}; flag form: recorded:true
Actual:   { "error": "phase, plan, and duration required" }
```

## GSD-SDK-007 — `state.record-metric` row lands under `## Deferred Items`, not `## Performance Metrics` (legacy: Phase 14 "metric rows land in the wrong table" / re-check item 5 / L-07)

**Source:** `.planning/milestones/v2.0-phases/14-workflow-foundation-and-action-pinning/deferred-items.md:32` ("STATE.md metric rows land in the wrong table") and `:55` (re-check row 5).

**Status:** REPRODUCES

**Expected:** the new metrics row is appended to the `## Performance Metrics` table. Research recorded the `| Phase 29.7 P01 |` row landing below `## Deferred Items` instead.

**Command:** `gsd-sdk query state.record-metric --phase 29.7 --plan 01 --duration 5min --tasks 2 --files 1 --project-dir <scratch-root>` (scratch copy, flag form), then a `grep -n` readback of the scratch STATE.md headings and the new row.

**Actual (v1.42.3, 2026-10-10):** the JSON reports `recorded: true`. Readback: the row is at line 616 (`| Phase 29.7 P01 | 5min | 2 tasks | 1 files |`); `## Performance Metrics` is at line 33, `## Deferred Items` at line 433 and the next heading, `## Session Continuity`, at line 618. The row sits inside the Deferred Items section.

**Workaround:** add the metrics row to `## Performance Metrics` by hand (Phase 29.7 D-02), or move the row after the call.

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L07.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query state.record-metric --phase 29.7 --plan 01 --duration 5min --tasks 2 --files 1 --project-dir <scratch-root>
Expected: the new "| Phase 29.7 P01 |" row lands below ## Deferred Items, not under ## Performance Metrics
Actual:   { "recorded": true, "phase": "29.7", "plan": "01", "duration": "5min" }
```

## GSD-SDK-008 — `state.add-decision` rejects the positional form (legacy: Phase 14 item 2 / D-19-D / Phase 23 item 7 / L-08)

**Source:** `.planning/milestones/v2.0-phases/14-workflow-foundation-and-action-pinning/deferred-items.md:15` (item 2); `.planning/milestones/v2.0-phases/19-pipeline-validation-via-branch-target-prs/deferred-items.md:59` (D-19-D) and `:75`; `.planning/phases/23-nexus-generic-chart/deferred-items.md:86` (item 7, last sentence: `add-decision` needs `--summary`).

**Status:** REPRODUCES

**Expected:** the positional form documented in the executor protocol (`state.add-decision "<text>"`) adds a decision. Research recorded `{"error":"summary required"}`.

**Command:** `gsd-sdk query state.add-decision "SCRATCH-... positional decision" --project-dir <scratch-root>` (scratch copy).

**Actual (v1.42.3, 2026-10-10):** `{"error": "summary required"}` (exit 0). The marker text is absent from the scratch STATE.md, and the frontmatter was not rewritten.

**Workaround:** use `--summary "<text>"` (and `--phase`, see GSD-SDK-009). In this repo decisions are written by hand instead (Phase 29.7 D-02).

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L08.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query state.add-decision SCRATCH-29.7-99315-32555\ positional\ decision --project-dir <scratch-root>
Expected: {"error":"summary required"}
Actual:   { "error": "summary required" }
```

## GSD-SDK-009 — `state.add-decision` writes `[Phase ?]` when `--phase` is not passed (legacy: Phase 14 item 2 / Phase 24 item 2 / L-09)

**Source:** `.planning/milestones/v2.0-phases/14-workflow-foundation-and-action-pinning/deferred-items.md:15` (item 2); `.planning/phases/24-nexus-anonymous-access-and-workstation-script/deferred-items.md:22` (item 2); `.planning/v3.0-MILESTONE-AUDIT.md:85` (general v2.0 carryovers); `.planning/PROJECT.md:130`. The live `[Phase ?]:` lines in `.planning/STATE.md` §Decisions (for example lines 158-234) are the accumulated output.

**Status:** REPRODUCES

**Expected:** the decision is prefixed with the current phase. Research recorded `- [Phase ?]: <text>` without `--phase` and `- [Phase 29.7]: <text>` with it.

**Command:** `gsd-sdk query state.add-decision --summary "SCRATCH-... flag decision" --project-dir <scratch-root>` (scratch copy), then `gsd-sdk query state.add-decision --phase 29.7 --summary "SCRATCH-... flag decision with phase" --project-dir <scratch-root>` in a second fresh copy.

**Actual (v1.42.3, 2026-10-10):** without `--phase`: `{"added": true, "decision": "- [Phase ?]: SCRATCH-... flag decision"}` (line 408). With `--phase 29.7`: line 408 reads `- [Phase 29.7]: SCRATCH-... flag decision with phase`. Both runs also rewrote the frontmatter (GSD-SDK-011).

**Workaround:** always pass `--phase` (holds on v1.42.3).

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L09.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query state.add-decision --summary SCRATCH-29.7-99315-32555\ flag\ decision --project-dir <scratch-root>
Expected: without --phase: "- [Phase ?]: <text>"; with --phase 29.7: "- [Phase 29.7]: <text>"
Actual:   { "added": true, "decision": "- [Phase ?]: SCRATCH-29.7-99315-32555 flag decision" }
```

## GSD-SDK-010 — `state.record-session` positional form drops Stopped At yet reports `recorded: true` (legacy: D-19-D / Phase 24 item 1 / L-10)

**Source:** `.planning/milestones/v2.0-phases/19-pipeline-validation-via-branch-target-prs/deferred-items.md:59` (D-19-D) and `:76`; `.planning/phases/24-nexus-anonymous-access-and-workstation-script/deferred-items.md:7` (item 1); `.planning/v3.0-MILESTONE-AUDIT.md:25` (Phase 23 "Deferred items 6-8") and `:85` (general v2.0 carryovers); `.planning/PROJECT.md:130`; `.planning/milestones/v2.0-MILESTONE-AUDIT.md:33`.

**Status:** REPRODUCES

**Expected:** the positional form documented in the executor protocol (`state.record-session "" "<stopped-at>" "<resume-file>"`) updates Stopped At, or fails loudly. Research recorded `recorded: true` with `updated` lacking "Stopped At" and the `Stopped at` body line unchanged.

**Command:** `gsd-sdk query state.record-session '' "SCRATCH-... positional stopped-at" None --project-dir <scratch-root>` (scratch copy).

**Actual (v1.42.3, 2026-10-10):** `{"recorded": true, "updated": ["Last session", "Resume File"]}` (exit 0). Readback: `620:Stopped at: Phase 29.7 context gathered` before and after; the stopped-at marker text appears nowhere in the scratch STATE.md; `Resume file:` became `None`. The frontmatter was also rewritten (GSD-SDK-011).

**Workaround:** use the flag form `--stopped-at "<text>" --resume-file "None"` (it reports `"Stopped At"` in `updated`), but note GSD-SDK-011. In this repo the session fields are written by hand (Phase 29.7 D-02).

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L10.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query state.record-session '' SCRATCH-29.7-99315-32555\ positional\ stopped-at None --project-dir <scratch-root>
Expected: recorded:true, "updated" lacks "Stopped At", and the STATE "Stopped at" body line is unchanged
Actual:   { "recorded": true, "updated": [ "Last session", "Resume File" ] }
```

## GSD-SDK-011 — Every STATE mutator rewrites the frontmatter `status`/`progress` without reporting it, including the flag form of `record-session` (legacy: Phase 14 item 3 / STATE 24-10 / L-11)

**Source:** `.planning/milestones/v2.0-phases/14-workflow-foundation-and-action-pinning/deferred-items.md:20` (item 3); `.planning/STATE.md:239` (24-10 "TOOL DEFECT OBSERVED" entry) and `:240`; `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/29.7-CONTEXT.md:167` (specifics, flag-form observation of 2026-10-08).

**Status:** REPRODUCES

**Expected:** a state handler changes only the fields it reports in `updated`. Research recorded the flag-form `record-session` reporting `updated: ["Last session","Stopped At","Resume File"]` while also rewriting `status: ready_to_plan` to `planning` and `completed_plans: 133` to `75`, unreported.

**Command:** `gsd-sdk query state.record-session --stopped-at "SCRATCH-..." --resume-file None --project-dir <scratch-root>` (scratch copy, flag form). The STATE.md lines 1-15 diff (fixture against scratch) was also captured for the flag `record-metric`, both `add-decision` runs, the positional `record-session`, `update-progress` and `phase.complete 29`.

**Actual (v1.42.3, 2026-10-10):** `{"recorded": true, "updated": ["Last session", "Stopped At", "Resume File"]}`. The frontmatter diff shows `status: ready_to_plan` -> `planning`, `completed_plans: 133` -> `75` and `last_updated` re-stamped (plus `stopped_at`, which is reported). Full set measured: the flag `record-metric`, `add-decision --summary` (with and without `--phase`), `record-session` (positional and flag) and `update-progress` each rewrote `status` -> `planning`, `completed_plans` 133 -> 75 and `last_updated`, and none reported it. `phase.complete 29` rewrote `status` -> `milestone_complete`, `stopped_at`, `completed_plans` 133 -> 135, `last_updated` (unquoted), and the body Current Position, focus and velocity. The rejected positional `record-metric` and `add-decision` calls wrote nothing.

**The flag form of `state.record-session` is not side-effect-free.** It was first observed on the real STATE.md on 2026-10-08 (Phase 29.7 discuss session: `status` and `completed_plans` rewritten unreported, then restored by hand) and was reproduced in the 2026-10-10 scratch re-test above. Switching from the positional form (GSD-SDK-010) to the flag form fixes Stopped At but not this rewrite.

**Workaround:** none in the tool. After any STATE mutator, diff STATE.md lines 1-15 and restore `status`, `progress` and `last_updated` by hand. This repo edits STATE.md by hand and does not run the mutators on the real `.planning/` (Phase 29.7 D-02).

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L11.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query state.record-session --stopped-at SCRATCH-29.7-99315-32555 --resume-file None --project-dir <scratch-root>
Expected: updated:["Last session","Stopped At","Resume File"] AND an unreported frontmatter rewrite (status: ready_to_plan -> planning, completed_plans: 133 -> 75)
Actual:   { "recorded": true, "updated": [ "Last session", "Stopped At", "Resume File" ] }
```

## GSD-SDK-012 — `state.update-progress` no-ops, yet still rewrites the frontmatter (legacy: Phase 14 item 4 / Phase 23 item 6 / Phase 24 item 3 / L-12)

**Source:** `.planning/milestones/v2.0-phases/14-workflow-foundation-and-action-pinning/deferred-items.md:24` (item 4); `.planning/phases/23-nexus-generic-chart/deferred-items.md:78` (item 6); `.planning/phases/24-nexus-anonymous-access-and-workstation-script/deferred-items.md:30` (item 3); `.planning/v3.0-MILESTONE-AUDIT.md:25` ("Deferred items 6-8") and `:85` (general v2.0 carryovers).

**Status:** REPRODUCES

**Expected:** the handler recalculates the STATE.md progress (this STATE.md carries progress as the frontmatter `progress:` map). Research recorded `{"updated":false,"reason":"Progress field not found in STATE.md"}` and, in addition, a frontmatter rewrite.

**Command:** `gsd-sdk query state.update-progress --project-dir <scratch-root>` (scratch copy).

**Actual (v1.42.3, 2026-10-10):** `{"updated": false, "reason": "Progress field not found in STATE.md"}` (exit 0). The frontmatter diff nevertheless shows `status` -> `planning`, `completed_plans` 133 -> 75 and `last_updated` re-stamped.

**Workaround:** set the `progress:` block by hand from a count of PLAN and SUMMARY files (Phase 29.7 D-02).

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L12.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query state.update-progress --project-dir <scratch-root>
Expected: {"updated":false,"reason":"Progress field not found in STATE.md"} and still a frontmatter rewrite
Actual:   { "updated": false, "reason": "Progress field not found in STATE.md" }
```

## GSD-SDK-013 — `roadmap.update-plan-progress` and `phase.complete` do not tick the milestone checklist line (legacy: Phase 23 item 8 / L-13)

**Source:** `.planning/phases/23-nexus-generic-chart/deferred-items.md:93` (item 8); `.planning/v3.0-MILESTONE-AUDIT.md:25` ("Deferred items 6-8").

**Status:** REPRODUCES

**Expected:** completing a phase ticks its `- [ ] **Phase NN:` line in the active milestone's checklist. Research recorded the line staying unticked in ROADMAP layouts A and B and being ticked in layout C.

**Command:** `gsd-sdk query roadmap.update-plan-progress 26 --project-dir <scratch-root>` (scratch copy, ROADMAP fixture `dbeabd7`, layout A), with a `grep -n 'Phase 26:'` readback before and after.

**Actual (v1.42.3, 2026-10-10):** `{"updated": true, "phase": "26", "plan_count": 7, "summary_count": 7, "status": "Complete", "complete": true}` (exit 0). Readback: `18:- [ ] **Phase 26: DefectDojo Generic Chart** ...` before and after. The only ROADMAP change was the progress table row (GSD-SDK-014).

**Root cause:** `sdk/dist/query/phase-roadmap-mutation.js:9-34` (in the installed get-shit-done-cc 1.42.3 package). `replaceInCurrentMilestone` assumes the active milestone follows the last `</details>`, and the `<details>` fallback regex ignores `<details open>` (located in Phase 29.7 research).

**Layout C adopted:** this repo moved `.planning/ROADMAP.md` to the template's Layout C in Phase 29.7 (operator ruling R-01, plan 29.7-05), the layout in which research observed the line being ticked. The scratch result above is on the layout A fixture. The first real confirmation on this repo's ROADMAP is the readback after Phase 29.7's own phase completion; until then the Layout C result rests on the research-session test.

**Workaround:** Layout C (R-01); otherwise tick the checklist line by hand after phase completion.

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L13.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query roadmap.update-plan-progress 26 --project-dir <scratch-root>
Expected: the milestone checklist line "- [ ] **Phase 26:" stays unticked (layout A)
Actual:   { "updated": true, "phase": "26", "plan_count": 7, "summary_count": 7, "status": "Complete", "complete": true }
```

## GSD-SDK-014 — `roadmap.update-plan-progress` and `phase.complete` re-stamp the completion date of an already-complete row (legacy: L-14, new)

**Source:** Phase 29.7 research, `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/29.7-RESEARCH.md:392` (Ledger Inventory, L-14), found 2026-10-08.

**Status:** NEW

**Expected:** running the handler on a phase whose progress row is already `Complete` leaves the recorded completion date alone. Research recorded the `| 26. DefectDojo Generic Chart |` row date changing from 2026-09-25 to the run date.

**Command:** `gsd-sdk query roadmap.update-plan-progress 26 --project-dir <scratch-root>` (scratch copy, the same run as GSD-SDK-013).

**Actual (v1.42.3, 2026-10-10):** `368:| 26. DefectDojo Generic Chart | v3.0 | 7/7 | Complete    | 2026-09-25 |` became `| ... | Complete   | 2026-10-10 |` (the run date, UTC; the cell padding also changed). Corroborated by the GSD-SDK-015 run: `phase.complete 29` re-stamped row 29 from `2026-09-29` to `2026-10-10`.

**Workaround:** do not run these handlers against an already-complete phase; if one is run, restore the original completion date by hand from git history.

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L14.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query roadmap.update-plan-progress 26 --project-dir <scratch-root>
Expected: the "| 26. DefectDojo Generic Chart |" row date changes from 2026-09-25 to the run date
Actual:   { "updated": true, "phase": "26", "plan_count": 7, "summary_count": 7, "status": "Complete", "complete": true }
```

## GSD-SDK-015 — `phase.complete` `**Plans:**` regex prefix-matches decimal phases (legacy: L-15, new)

**Source:** Phase 29.7 research, `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/29.7-RESEARCH.md:393` (Ledger Inventory, L-15), found 2026-10-08. Research located the regex at `phase-lifecycle.js:901`, which lacks the `(?=[:\s])` lookahead present at `roadmap-update-plan-progress.js:93`.

**Status:** NEW

**Expected:** `phase.complete 29` updates only Phase 29's `**Plans:**` line. Research recorded the Phase 29.1 block's `**Plans:** 2/2 plans complete` becoming `**Plans:** 20/20 plans complete`.

**Command:** `gsd-sdk query phase.complete 29 --project-dir <scratch-root>` (scratch copy, ROADMAP fixture `dbeabd7`, layout A).

**Actual (v1.42.3, 2026-10-10):** the 29.1 block (line 382) changed from `**Plans:** 2/2 plans complete` to `**Plans:** 20/20 plans complete`, while Phase 29's own line `222:**Plans:** 20 plans in 14 waves` was left unchanged. Extra observations from the same run: the output says `"is_last_phase": true, "next_phase": null` (layout A analyze sees 7 phases), and it says `"requirements_updated": true` although the REQUIREMENTS.md diff is empty. STATE side effects are listed under GSD-SDK-011.

**Workaround:** after `phase.complete` on a phase that has decimal siblings (for example 29 and 29.1), check every `**Plans:**` line of the sibling phases and restore them by hand.

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L15.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query phase.complete 29 --project-dir <scratch-root>
Expected: the 29.1 block "**Plans:** 2/2 plans complete" becomes "**Plans:** 20/20 plans complete"
Actual:   { "completed_phase": "29", "phase_name": "defectdojo-live-validation", "plans_executed": "20/20", "next_phase": null, "next_phase_name": null, "is_last_phase": true, "date": "2026-10-10", "roadmap_updated": true, "state_updated": true, "requirements_updated": true, "warnings": [], "has_warnings": false }
```

## GSD-SDK-016 — The frontmatter parser keeps YAML trailing comments inside the value (legacy: L-16, new)

**Source:** Phase 29.7 research, `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/29.7-RESEARCH.md:394` (Ledger Inventory, L-16), found 2026-10-08.

**Status:** NEW

**Expected:** a YAML trailing comment (`key: value  # comment`) is not part of the value. Research recorded the trailing `# Marked only after ...` comment being kept inside the value, with `summary-extract` returning it as a single string element.

**Command:** `gsd-sdk query frontmatter.get .planning/phases/24-nexus-anonymous-access-and-workstation-script/24-10-SUMMARY.md requirements-completed` (read-only, real repo), plus `summary-extract --pick` on the same file.

**Actual (v1.42.3, 2026-10-10):** `frontmatter.get`: `{"requirements-completed": "[NEXUS-02, NEXUS-04]  # Marked only after git ls-tree origin/main evidence — see Task 3."}`; `summary-extract --pick`: `["[NEXUS-02, NEXUS-04]  # Marked only after git ls-tree origin/main evidence — see Task 3."]` (one string element; the source line is 53). The paste-ready block below shows a single space before `#` only because the harness squeezes runs of spaces.

**Live affected files** (trailing-comment `requirements-completed:` on the key line, grep of 2026-10-09):

- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-01-SUMMARY.md:48`
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-02-SUMMARY.md:51`
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-04-SUMMARY.md:45`
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-05-SUMMARY.md:50`
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-06-SUMMARY.md:48`
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-07-SUMMARY.md:57`
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-08-SUMMARY.md:54`
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-09-SUMMARY.md:59`
- `.planning/phases/24-nexus-anonymous-access-and-workstation-script/24-10-SUMMARY.md:53`

The same grep also matches `.planning/phases/27-defectdojo-ci-auto-import/27-01..27-09-SUMMARY.md` and archived v2.0 SUMMARYs under `.planning/milestones/v2.0-phases/` (14-02, 20-01, 20-04..20-13, 22-01..22-05). These are recorded here for completeness and are not modified by this ledger.

**Workaround:** put the comment on the line above the key, not after the value (operator ruling R-02, Phase 29.7; used by plan 29.7-01 for the SUMMARYs it added `requirements-completed` to). To read existing files correctly, parse with `yq --front-matter=extract '.["requirements-completed"]' <file>`, which returns `["NEXUS-02", "NEXUS-04"]` for 24-10 (checked 2026-10-09 with yq v4.54.1).

**Evidence:** `.planning/phases/29.7-bookkeeping-roadmap-checkboxes-requirements-completed-frontm/evidence/29.7-ledger-L16.txt`

```text
gsd-sdk version: gsd-sdk v1.42.3
Command:  gsd-sdk query frontmatter.get .planning/phases/24-nexus-anonymous-access-and-workstation-script/24-10-SUMMARY.md requirements-completed
Expected: the trailing "# Marked only after ..." comment is kept inside the value (frontmatter.get) and summary-extract returns it as a single string element
Actual:   { "requirements-completed": "[NEXUS-02, NEXUS-04] # Marked only after git ls-tree origin/main evidence — see Task 3." }
```
