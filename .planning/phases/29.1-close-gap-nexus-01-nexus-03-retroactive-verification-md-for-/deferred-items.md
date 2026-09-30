# Phase 29.1 — Deferred Items

Out-of-scope discoveries logged during execution. Not actioned in the plan that found them.

This ledger holds only findings about the **verification tooling** surfaced while authoring
`.planning/phases/23-nexus-generic-chart/23-VERIFICATION.md` (routing convention of `20.1-03-SUMMARY.md:31`).
Findings about Phase 23's own subject are in `.planning/phases/23-nexus-generic-chart/deferred-items.md`
(`## Status re-check 2026-09-29 (Phase 29.1)`). None of the entries below changes a verdict in `23-VERIFICATION.md`.
Every literal output is copied from `23-VERIFICATION.md` (§Method, §Required Artifacts, §Key Link Verification,
§Probe Execution) or from `29.1-01-SUMMARY.md`, where it was observed. None was re-run for this ledger.

## D-29.1-A — `frontmatter.get --field` errors; the positional form nests the result (found: plan 29.1-01)

**Expected:** the verify workflow's form returns the plan's `must_haves` block, so `.truths` can be counted directly.

**Command:** `gsd-sdk query frontmatter.get <plan> --field must_haves`

**Output:** `{"error":"Field not found","field":"--field"}`. The handler reads `--field` as the field name.
The positional form (`frontmatter.get <plan> must_haves`) works, but it nests the result under `.must_haves`,
so a naive `jq '.truths'` read yields 0 truths instead of the 35 the eight Phase 23 plans declare.
29.1-01 worked around it with `yq --front-matter=extract '.must_haves.truths[]' 23-0N-PLAN.md` (23-VERIFICATION.md §Method).

**Not actioned here:** Phase 29.1 is a documentation gap-closure phase, and fixing `gsd-sdk` is outside its scope.
The workaround is recorded in the report's Method, so the truth count stays reconstructible.

**Owner:** gsd-sdk tooling maintainers.

## D-29.1-B — `verify.key-links` false negatives on double-escaped patterns (found: plan 29.1-01)

**Expected:** a key link whose pattern matches the source file is reported as verified.

**Command:** `gsd-sdk query verify.key-links <plan>`, run for each of 23-01 through 23-08 (probe P-d).

**Output:** 23-02 `1/2`, 23-03 `1/2`, 23-07 `0/1`. The plan frontmatter stores patterns such as `provision\\.sh`.
The tool matches that as a literal backslash followed by any character, so a correct source line cannot match.
Each link was re-verified manually, and every one held: the 23-02 grep at L54, `Chart.yaml:8` for 23-03, and
`docs/adr/README.md:30` for 23-07 (23-VERIFICATION.md §Key Link Verification, §Probe Execution).

**Not actioned here:** the defect is in how the tool unescapes the patterns (or how the planner escapes them), not in
Phase 23's plans. It sits outside a documentation gap-closure phase, and the closed Phase 23 plans are not rewritten.

**Owner:** gsd-sdk tooling maintainers.

## D-29.1-C — `verify.key-links` reports "Source file not found" for branch-to-branch links (found: plan 29.1-01)

**Expected:** a link whose `from` is a branch (`feature/phase-23-nexus-generic-chart` → `security-platform` `main`)
is either verified against the remote or reported as not file-checkable.

**Command:** `gsd-sdk query verify.key-links .planning/phases/23-nexus-generic-chart/23-08-PLAN.md`

**Output:** `0/1`, "Source file not found". The link's source is a remote fact, not a file. The substitute evidence
was N1-b: PR #14 `MERGED`, merge `ea2770f…`, `mergedBy` `is_bot: false`, `type: User`, and `ea2770f` is an ancestor
of `origin/main` (23-VERIFICATION.md §Key Link Verification row for 23-08).

**Not actioned here:** the fix is a tool change (recognise non-file link sources), which sits outside a documentation
gap-closure phase.

**Owner:** gsd-sdk tooling maintainers.

## D-29.1-D — `verify.artifacts` `min_lines` under-scores long-paragraph ADRs (found: plan 29.1-01)

**Expected:** ADR-020 (`docs/adr/adr020-nexus-chart-base-and-eula-opt-in.md`, 19,622 bytes, four `##` sections)
passes its artifact check as a substantive document.

**Command:** `gsd-sdk query verify.artifacts .planning/phases/23-nexus-generic-chart/23-07-PLAN.md`

**Output:** `2/3`, with "Only 49 lines, need 60" on ADR-020, while `wc -l` reports 48 (the tool also counts the line after
the trailing newline). `min_lines` counts physical lines, so a document written as long one-line paragraphs scores as a stub.
23-07-SUMMARY:106 records "47 content lines" (23-VERIFICATION.md §Required Artifacts).

**Not actioned here:** `docs/adr/` is append-only (CLAUDE.md), so ADR-020 is not reflowed to satisfy a line counter.
The real fix is a size measure that reflects content (bytes, or non-empty lines weighted by length), which is a tool change.

**Owner:** gsd-sdk tooling maintainers.

## D-29.1-E — `verify.artifacts` errors instead of reporting 0/0 on plans without file artifacts (found: plan 29.1-01)

**Expected:** a plan that has no file artifacts by design (a run plan or a merge plan) is reported as having nothing to check.

**Command:** `gsd-sdk query verify.artifacts .planning/phases/23-nexus-generic-chart/23-06-PLAN.md` (and the same for `23-08-PLAN.md`)

**Output:** `error: No must_haves.artifacts found in frontmatter` for both plans. 23-06 is a run plan and 23-08 is a merge plan,
so neither declares file artifacts. The error shape makes a legitimately empty set look like a malformed plan
(23-VERIFICATION.md §Probe Execution; queued for this ledger in 29.1-01-SUMMARY).

**Not actioned here:** this is informational. No verdict depends on it, and the fix, a tool change, sits outside a
documentation gap-closure phase.

**Owner:** gsd-sdk tooling maintainers.
