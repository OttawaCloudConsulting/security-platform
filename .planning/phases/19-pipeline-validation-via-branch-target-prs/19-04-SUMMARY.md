---
phase: 19-pipeline-validation-via-branch-target-prs
plan: 04
subsystem: ci-cd
tags: [code-scanning, semgrep, sarif, security-tab, sc3, trace, checkpoint]

# Dependency graph
requires:
  - phase: 19-01
    provides: fixtures/vulnerable.py with the eval() call at line 20 — the hop-1 anchor
  - phase: 19-03
    provides: PR #10 at head d8bd09b and run 34786019516 — the only run on the branch, and the sole source this trace is scoped to
  - phase: 17-06
    provides: ADR-016 D-02 (pull_request-only trigger), which is why the unfiltered alerts list reads empty
provides:
  - "SC3's three-hop trace — source line 20 → code-scanning alert 98 → semgrep-results.json line 20, agreeing on rule and line"
  - "alert 98's html_url: https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning/98"
  - "the unfiltered-vs-ref-filtered CONTROL pair, recorded as by-design rather than as a fault"
  - "analysis 1769518474 — the link that proves the alert and the artifact came from the same run"
affects: [19-05, 19-06, 19-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Alerts read only through ref=refs/pull/<N>/merge with tool_name=Semgrep%20OSS — never from the unfiltered list"
    - "Every API response recorded next to the query string that produced it (T-19-15)"
    - "Agreement asserted across hops on rule id AND line number, shown as three numbers side by side, not claimed"
    - "The artifact re-downloaded independently of plan 03 into a fresh directory, with sha256, so the trace stands on its own evidence"

key-files:
  created:
    - .planning/phases/19-pipeline-validation-via-branch-target-prs/19-04-SUMMARY.md
  modified: []

key-decisions:
  - "Task 2 is a blocking checkpoint and the plan HALTS here. Auto-advance is off (workflow._auto_chain_active=false), the orchestrator instructed a clean halt, and the acceptance criteria require the operator's reply VERBATIM — auto-approving would fabricate the exact evidence T-19-15 exists to prevent."
  - "The single-alert endpoint returns state: null while the list endpoint returns state: open for the same alert 98. Recorded as an observed endpoint-shape discrepancy, NOT reconciled and NOT silently dropped. It is a difference in the reader, not in the finding."
  - "VAL-01 NOT marked complete — following 19-01/19-02/19-03 and the 17-01 precedent. SC2 is still unmeasured (plan 05) and this plan's own SC3 is only half-closed until the operator replies."
  - "Nothing was pushed, merged, closed, re-run, or GATE_MODE-touched. Every command in this plan is a read."

patterns-established:
  - "When a criterion's evidence path is a UI observation, capture the full API evidence AND hand the human exactly ONE url with ONE yes/no question — the RESEARCH Q2 remedy for what cost Phase 17 a criterion"

requirements-completed: []

# Metrics
duration: 9min (Task 1 only — HALTED at Task 2 checkpoint)
completed: 2026-09-13
---

# Phase 19 Plan 04: Trace One Seeded SAST Finding to the Security Tab Summary

**The `eval()` call at `fixtures/vulnerable.py:20` was followed to code-scanning alert **98**
(`python.lang.security.audit.eval-detected.eval-detected`, `refs/pull/10/merge`,
[html_url](https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning/98)) and to the
matching entry in the independently re-downloaded `semgrep-results.json` — **all three hops reporting line 20
and the same rule** — while the unfiltered alerts list returned `[]`, exactly as ADR-016 D-02 predicts.**

**STATUS: HALTED at Task 2.** Task 1 is complete and committed. Task 2 is a blocking
`checkpoint:human-verify` and the operator's reply has not been received. SC3's UI half is **not yet
observed**; see [Operator Reply](#operator-reply-task-2--pending).

## Scope note

This trace is scoped to the values recorded in 19-03-SUMMARY and re-read, never guessed:

| Scoped to | Value | Source | Re-read here |
|---|---|---|---|
| PR | **10** | 19-03-SUMMARY | `gh pr view feature/phase-19-pipeline-validation --json number` → `10` |
| Head SHA | `d8bd09bbbb8d34666cddb7afb0b2c4e3b4c4dca1` | 19-03-SUMMARY | `gh pr view 10 --json headRefOid` → same |
| Run | **34786019516** | 19-03-SUMMARY | `gh run list --branch …` → count **1**, that id, `success` |

The re-derivation agreed with the recorded value in all three cases, so no ambiguity about which PR, which
commit or which run this evidence describes.

## The three-hop trace — three line numbers side by side

| Hop | What | Rule / check_id | Path | **Line** |
|---|---|---|---|---|
| **1 — source** | `repos/security-platform/fixtures/vulnerable.py`, committed at `d8bd09b` | *(the anchor)* | `fixtures/vulnerable.py` | **20** |
| **2 — Security tab entry** | code-scanning alert **98**, read through `ref=refs/pull/10/merge&tool_name=Semgrep%20OSS` | `python.lang.security.audit.eval-detected.eval-detected` | `fixtures/vulnerable.py` | **20** |
| **3 — retained artifact** | `semgrep-results.json` inside artifact `semgrep-results` (id `10326766234`), re-downloaded for this plan | `python.lang.security.audit.eval-detected.eval-detected` | `fixtures/vulnerable.py` | **20** |

**Agreement: `20 | 20 | 20`**, measured — not asserted. The verify script printed it:

```
grep line: 20 | artifact line: 20 | rule: python.lang.security.audit.eval-detected.eval-detected
rc=0
```

The rule string is **byte-identical** between hop 2 (`rule.id` from the alerts API) and hop 3 (`check_id` in
the JSON artifact): `python.lang.security.audit.eval-detected.eval-detected`. No discrepancy anywhere in the
three hops — nothing had to be reconciled, and nothing was.

### Hop 1 — the source, read from the committed file

```
$ grep -n 'eval(' repos/security-platform/fixtures/vulnerable.py
20:    return eval(user_input)
rc=0
```

**Exactly one match.** Line 20, text `    return eval(user_input)`, inside `def run_expression(user_input):`
(line 19). The file's own header comment at line 7 names `eval-detected` but contains no `eval(` substring,
so neither `grep` nor the verify script's comment filter had anything to exclude — both independently land on
20.

### Hop 2 — the Security tab entry, through the ref filter

Query, recorded with its response (T-19-15 — the only trustworthy read is an API response recorded with its
query):

```
$ gh api "repos/OttawaCloudConsulting/security-platform/code-scanning/alerts?ref=refs/pull/10/merge&tool_name=Semgrep%20OSS"
TOTAL ALERTS RETURNED: 8
```

**8 alerts** — matching exactly the 8 Semgrep results 19-03 measured in the artifact. The three on
`fixtures/vulnerable.py`:

| # | Rule id | Line | State | `html_url` |
|---|---|---|---|---|
| **98** | `python.lang.security.audit.eval-detected.eval-detected` | **20** | `open` | **https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning/98** |
| 99 | `python.lang.security.audit.exec-detected.exec-detected` | 24 | `open` | https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning/99 |
| 100 | `python.lang.security.audit.subprocess-shell-true.subprocess-shell-true` | 32 | `open` | https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning/100 |

**Alert 98 is the trace subject.** 99 and 100 are corroboration: all three seeded SAST findings landed, at the
three lines the fixture's own header comment predicted (20 / 24 / 32).

Alert 98 in full, from `code-scanning/alerts/98`:

| Field | Value |
|---|---|
| `number` | **98** |
| `rule.id` | `python.lang.security.audit.eval-detected.eval-detected` |
| `rule.severity` | `warning` |
| `rule.security_severity_level` | `null` |
| `tool.name` / `tool.version` | **`Semgrep OSS`** / `1.177.0` |
| `most_recent_instance.ref` | **`refs/pull/10/merge`** |
| `most_recent_instance.commit_sha` | `b6123ab3328c013db621f6de77613aeaf739e62f` |
| `…location.path` | `fixtures/vulnerable.py` |
| `…location.start_line` / `end_line` | **20** / 20 |
| `created_at` | `2026-09-13T22:11:36Z` |
| `html_url` | `https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning/98` |
| `message.text` | "Detected the use of eval(). eval() can be dangerous if used to evaluate dynamic content. …" |

Two things worth naming rather than passing over:

- **`tool.version` reads `1.177.0`** — the CI-pinned Semgrep, matching 19-01's local pin. The alert was
  produced by the same tool version the fixture was measured against, so Pitfall 8's registry-drift risk did
  not materialise between 19-01 and this read.
- **`commit_sha` is `b6123ab3…`, not `d8bd09b…`.** That is the *merge* commit of `refs/pull/10/merge`, which
  is what a `pull_request`-triggered run checks out — and it is the same SHA 19-03 recorded in the container
  job's image tag `scan-fixture:b6123ab3328c013db621f6de77613aeaf739e62f`. Not a discrepancy; two jobs in one
  run reporting the same `GITHUB_SHA`.

**Observed endpoint discrepancy, recorded not reconciled.** The **list** endpoint returns `"state": "open"`
for alert 98; the **single-alert** endpoint `code-scanning/alerts/98` returns `"state": null` for the same
alert in the same minute. Both responses are quoted above as returned. This is a difference in how the two
readers render the field, not a difference in the finding — every identity field (`number`, `rule.id`,
`path`, `start_line`, `ref`, `html_url`) is identical across both. Recorded here so a later plan comparing
`state` across endpoints does not read it as drift.

### Hop 2 CONTROL — the unfiltered list, empty by design

```
$ gh api "repos/OttawaCloudConsulting/security-platform/code-scanning/alerts?per_page=3"
[]
$ … --jq 'length'
0
```

**`0`. This is by design, not by fault.** Per **ADR-016 D-02**
(`docs/adr/adr016-sarif-upload-attribution-and-artifact-retention.md`, line 28): *"The workflow trigger stays
`pull_request`-only; `push: branches: [main]` is deliberately NOT added (user decision D-02). … **`main` is
never analysed**, so no alert this phase produces is associated with the default branch. The unfiltered
Security tab therefore reads empty."* The ADR's Consequences section names the same thing as an accepted
tradeoff (line 47).

**No `push:` trigger was added, and no workflow file was touched.** `git diff origin/main --name-only` in the
inner repo still lists exactly the same four paths as 19-03 recorded — `fixtures/README.md`,
`fixtures/secret.env`, `fixtures/vulnerable.py`, `scripts/smoke-scans.sh` — none of them a workflow (T-19-16).

This pair is the whole point of the control: **the same repository, the same minute, one query returns the
alert and the other returns `[]`.** The filter is what makes the evidence visible; its absence is the locked
ADR working as decided.

### Hop 3 — the retained artifact, downloaded independently of plan 03

```
$ gh run download 34786019516 -R OttawaCloudConsulting/security-platform -n semgrep-results -D "$SCRATCH/19-trace"
rc=0
```

A **fresh** directory (`rm -rf` then `mkdir -p`), not plan 03's, so this trace rests on its own download.
`-R` was passed explicitly — the working directory is the outer docs repo, whose remote is a different
repository, so an inferred repo would have 404'd. File listing with sizes, enumerated not assumed:

| File | Bytes | sha256 |
|---|---|---|
| `semgrep-results.json` | 45,593 | `99021a0539abf0340dc6f5b722350f80078ff7b190516a8e7735e94ef0cb8421` |
| `semgrep.sarif` | 2,129,136 | `99d55587e45db2148452d50ee6ba4079bb8679c3d3c37b4123c0e49e747095d2` |

Artifact identity, re-read from the API rather than carried over from 19-03:

| Field | Value |
|---|---|
| `id` | **10326766234** |
| `name` | `semgrep-results` |
| `size_in_bytes` | 197,864 (the zip; the two unpacked files are listed above) |
| `expired` | **`false`** |
| `expires_at` | `2026-12-12T22:11:04Z` |
| `workflow_run.id` | **34786019516** |
| `workflow_run.head_sha` | `d8bd09bbbb8d34666cddb7afb0b2c4e3b4c4dca1` |

Every result in `semgrep-results.json` whose `path` contains `vulnerable.py`, as `(check_id, path, start.line)`:

```
('python.lang.security.audit.eval-detected.eval-detected',               'fixtures/vulnerable.py', 20)
('python.lang.security.audit.exec-detected.exec-detected',               'fixtures/vulnerable.py', 24)
('python.lang.security.audit.subprocess-shell-true.subprocess-shell-true','fixtures/vulnerable.py', 32)
rc=0
```

Three results, at 20 / 24 / 32 — the same three rules and the same three lines as alerts 98 / 99 / 100. The
assertion exits **3** if `eval-detected` is absent; it exited **0**.

### The link that makes it one finding rather than three coincidences

The alert and the artifact are not merely consistent — they are provably the **same run's output**:

| Evidence | Alert side | Artifact side |
|---|---|---|
| Analysis | `code-scanning/analyses?ref=refs/pull/10/merge` → id **1769518474**, category `semgrep`, tool `Semgrep OSS`, `results_count` **8**, `created_at` `2026-09-13T22:11:36Z` | — |
| Run | alert `commit_sha` `b6123ab3…` = the merge SHA of run 34786019516 | `workflow_run.id` = **34786019516** |
| Count | 8 alerts returned under the `Semgrep OSS` ref filter | 8 results in `semgrep-results.json` (19-03, re-confirmed by `results_count: 8`) |
| Timestamp | alert `created_at` `22:11:36Z` = analysis `created_at` | artifact `created_at` `22:11:42Z`, same run |

The analyses query was not in the plan's command list; it was added because "the hops agree on rule and line"
is satisfiable by two independent scans of the same file, whereas a shared analysis id and run id is not
(T-19-17).

## Post-state — nothing was changed

Every command in this plan is a read. Verified after the fact, not assumed:

| Item | Command | Result |
|---|---|---|
| PR #10 | `gh pr view 10 --json state,headRefOid,mergeable` | **`OPEN`**, `d8bd09bbbb8d34666cddb7afb0b2c4e3b4c4dca1`, `MERGEABLE` |
| Runs on the branch | `gh run list --branch feature/phase-19-pipeline-validation` | **1** — `34786019516`, `success`. No new run. |
| `GATE_MODE` | `gh variable list -R …` | **empty** (zero lines) — untouched; plan 05 still owns the flip |
| Inner working tree | `git -C repos/security-platform status --short` | **clean** |
| Branch vs `origin/main` | `git -C repos/security-platform diff origin/main --name-only` | the same **four** paths — no workflow file among them |
| Outer repo | this plan's `files_modified: []` | only this SUMMARY was written |

No push, no merge, no close, no re-run, no `GATE_MODE` change, no `.gitleaksignore` edit, no package install.

## Operator Reply (Task 2) — PENDING

**The plan is HALTED here.** Task 2 is `checkpoint:human-verify` with `gate="blocking"`, and its acceptance
criteria require *"The operator's reply is recorded VERBATIM in the SUMMARY, whatever it says."*

| Field | Value |
|---|---|
| The single URL handed to the operator | `https://github.com/OttawaCloudConsulting/security-platform/security/code-scanning/98` |
| The one question | Does that page render an alert naming `fixtures/vulnerable.py`, rule `eval-detected`, line **20**? |
| Operator reply | **PENDING — not yet received. To be recorded here VERBATIM by the continuation agent, whatever it says.** |
| SC3 UI half | **NOT YET OBSERVED** |

**Why this was not auto-approved.** Auto-advance is off (`workflow._auto_chain_active` = `false`,
`workflow.auto_advance` unset), the plan is `autonomous: false`, and the orchestrator instructed a clean halt
at any defined checkpoint. More importantly, the deliverable of Task 2 *is* the human's words. Writing
"approved" without having asked would be precisely the substitution T-19-15 exists to prevent — API evidence
dressed up as the UI observation that was requested — and it is the failure mode RESEARCH Q2 designed this
checkpoint to foreclose.

**What is already secured regardless of the reply:** the API half of SC3 is complete and measured above. If
the operator confirms, SC3 closes MET on both halves. If the operator reports something different, the reply
is recorded verbatim and the plan STOPS — no re-query, no re-trace, no substituted finding.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `-R` added to the hop-3 `gh run download`.**
- **Found during:** Task 1, hop 3.
- **Issue:** The plan's hop-3 command (`gh run download <RUN> -n semgrep-results -D …`) omits `-R`. The
  working directory is the **outer** docs repo, whose remote is not `OttawaCloudConsulting/security-platform`,
  so `gh` would have inferred the wrong repository and failed to find run `34786019516`.
- **Fix:** added `-R OttawaCloudConsulting/security-platform`, which is what 19-RESEARCH §Code Examples
  already shows. No other change; the artifact name, run id and `-D` directory are the plan's.
- **Files modified:** none — a command-line correction, not a file edit.

No Rule 1 or Rule 2 fix was required. Nothing else in the plan's commands needed correction.

### Intentional additions

**2. The `code-scanning/analyses` query was added.** Not in the plan's command list. Added because agreement
on rule and line alone does not distinguish "one finding seen three ways" from "three independent
observations that happen to match" — T-19-17's exact concern. The shared analysis id `1769518474` and run id
`34786019516` close that gap. Recorded in its own section above.

**3. sha256 of both unpacked artifact files recorded.** So a later plan re-downloading the same artifact can
confirm byte-identity rather than re-parse it.

**4. `tool.version` and `most_recent_instance.ref` captured from the alert.** Not requested. The first
confirms Pitfall 8's registry drift did not occur between 19-01's local measurement and this read; the second
is the ref filter's own value echoed back by the server, which is what makes "read through a ref filter on
`refs/pull/<N>/merge`" a measurement rather than a claim about the query string.

**5. VAL-01 NOT marked complete.** The plan frontmatter lists `requirements: [VAL-01]` and the executor
template marks listed requirements complete. Withheld, following 19-01, 19-02, 19-03 and the 17-01 precedent:
SC2 is unmeasured (plan 05), and this plan's own SC3 is half-open until the operator replies.
`requirements.mark-complete` was deliberately not invoked.

### Checkpoints

**Task 2 — reached and HALTED.** See [Operator Reply](#operator-reply-task-2--pending). This is the plan
working as designed, not a failure: `autonomous: false` exists for exactly this task.

### Authentication gates

None. `gh` was already authenticated (`OttawaCloudConsulting`, scopes `gist, read:org, repo, workflow`). No
package was installed and no dependency manifest was touched.

## Issues Encountered

None unresolved. One observation that could be misread and is not a problem:

- **`state: null` from `code-scanning/alerts/98` vs `state: "open"` from the list endpoint.** Documented
  above under Hop 2. Both quoted as returned; neither was edited to agree with the other.

## Handoff Notes

1. **The continuation agent's ONLY job on resume is to record the operator's reply verbatim** in the
   *Operator Reply* section, flip *SC3 UI half* from NOT YET OBSERVED to its measured outcome, and then run
   the state updates (`state.advance-plan`, `state.update-progress`, `state.record-metric`,
   `roadmap.update-plan-progress`). Those were deliberately **not** run by this session — the plan is not
   complete until Task 2 is.
2. **Do not re-run the trace on resume.** The evidence above is scoped to run `34786019516`, which is still
   the only run on the branch. Re-querying after plan 05's empty commits would produce *different* alert
   numbers for the same findings.
3. **Alert numbers 98/99/100 are Phase 19's; 86/87/88 are the Phase 17 baseline findings** (`dependabot.yml`,
   `security.yml`, `Dockerfile`) and are still open on this PR. A later plan comparing alert counts should
   expect **8**, not 3 and not 5.
4. **Artifacts expire `2026-12-12T22:11:04Z`.** The unpacked copies live in this session's scratchpad only —
   not durable, and deliberately outside both repositories.
5. **Plan 05 still owns the `GATE_MODE` flip, and `gh variable list` is still empty** — the restore target
   remains *deletion*, not "set back to report-only", exactly as 19-03 recorded.

## Self-Check: PASSED

| Claim | Verification | Result |
|---|---|---|
| This SUMMARY exists at the path the plan names | `[ -f .planning/phases/19-…/19-04-SUMMARY.md ]` | FOUND |
| `must_haves.artifacts[0].contains: html_url` | `grep -c 'html_url'` | present (frontmatter, hop-2 table, alert-98 table, operator section) |
| `key_links[0].pattern: code-scanning/alerts\?ref=refs/pull` | the hop-2 query string is recorded verbatim | FOUND |
| `key_links[1].pattern: eval-detected` | hop-2 rule id and hop-3 `check_id` | FOUND in both |
| Hop 1 line | `grep -n 'eval('` | `20:    return eval(user_input)` |
| Hop 2 line | alerts API, alert 98 | `20` |
| Hop 3 line | `semgrep-results.json` | `20` |
| PR still OPEN, 1 run, no variable | `gh pr view` / `gh run list` / `gh variable list` | `OPEN` / `1` / empty |

Every figure in this SUMMARY was read from a command's recorded output in **this** session. Nothing was
carried over from 19-03 without being re-read, and no figure anywhere is a UI impression — the one UI
observation this plan requires is explicitly marked PENDING rather than inferred (T-19-13, T-19-15).
