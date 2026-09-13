# Phase 19 — Deferred Items

Out-of-scope discoveries logged during execution. Not actioned in the plan that found them.

## D-19-A — `fixtures/README.md` edit point 4 understates the control stack (found: plan 19-03, Task 1)

`fixtures/README.md` (as committed at `d8bd09b` by plan 19-02) states that `git push --no-verify` is the
bypass for the pre-push Gitleaks hook and that "CI is the compensating control."

Measured 2026-09-13 during 19-03: that is incomplete. A **server-side** control sits between the local hook
and CI — GitHub Push Protection rejected `git push --no-verify` with `GH013` on `fixtures/secret.env` lines
21 and 22 (Amazon AWS Access Key ID, Amazon AWS Secret Access Key), naming commit `fbfcbe9`. `--no-verify`
is a client-side flag and cannot skip it.

The measured layering is the **inverse** of what the repo documents:

| Layer | Documented expectation | Measured 2026-09-13 |
|---|---|---|
| pre-commit hook (`stages: [pre-push]`, `--staged`) | fires on the fixture | **no-op** — `0 commits scanned`, `no leaks found`, rc=0 |
| GitHub Push Protection | not mentioned anywhere | **blocks the push** |
| CI `secrets` job (`gitleaks git .`) | the compensating control | not yet reached |

**Not actioned here:** plan 19-03 requires the branch to be exactly what 19-02 left (four paths), so the
README must not be amended before the push. Owner: a later plan in this phase, or Phase 20.

## D-19-B — Secret Scanning is eligible but disabled (found: plan 19-03, Task 1)

`repos/OttawaCloudConsulting/security-platform` reports
`security_and_analysis.secret_scanning.status = "disabled"` (also `secret_scanning_push_protection:
disabled`), while the push rejection notes the repo "does not have Secret Scanning enabled, but is
eligible." Push protection fired regardless, because free push protection for **public** repositories is
controlled at the account level, not by the repo-level `security_and_analysis` block.

**Not actioned here:** enabling Secret Scanning mid-phase would change the measurement conditions for
plans 04-06. Recorded as an observation for plan 07 / Phase 20.

**Update, measured 2026-09-13 after the user approved the two unblock URLs (reason: "used in tests"):** the
push then succeeded (`* [new branch] feature/phase-19-pipeline-validation`, rc=0), and
`gh api repos/OttawaCloudConsulting/security-platform --jq .security_and_analysis` **still** reports
`secret_scanning: disabled` and `secret_scanning_push_protection: disabled`. So the per-secret allowance is a
bypass recorded against the two specific blobs, not an enablement of the feature — the repo-level
`security_and_analysis` block remains a misleading place to look for whether push protection is in force on
this repository. Both facts stand together and neither cancels the other.

## D-19-C — pre-commit Gitleaks hook is structurally a no-op (carried from 19-02 Handoff Note 7)

`stages: [pre-push]` + an entry of `gitleaks git --pre-commit --redact --staged --verbose` means the hook
never runs at commit and scans an empty staged diff at push. Re-confirmed at push scope in 19-03 by invoking
the installed `.git/hooks/pre-push` with git's exact stdin line: rc=0, `Detect hardcoded secrets ... Passed`.

**Not actioned here:** CONTEXT forbids config changes in this phase. Fix options remain as 19-02 recorded:
move to `stages: [pre-commit]` so `--staged` is meaningful, or change the entry to a history scan.

## D-19-D — `gsd-sdk` state handlers take NAMED flags, not the positional args the executor template documents

Observed during 19-04's resume, 2026-09-13. The executor agent template prescribes positional invocations:

```
gsd-sdk query state.record-metric "${PHASE}" "${PLAN}" "${DURATION}" "${TASK_COUNT}" "${FILE_COUNT}"
gsd-sdk query state.add-decision "${decision}"
gsd-sdk query state.record-session "" "Completed X-PLAN.md" "None"
```

The installed SDK (`get-shit-done-cc`, global) parses these with `parseNamedArgs`, so all three silently
mis-fire. Measured, not inferred:

| Invocation | Result |
|---|---|
| `state.record-metric "19" "04" "11min" "2" "1"` | `{"error":"phase, plan, and duration required"}` |
| `state.add-decision "<text>"` | `{"error":"summary required"}` |
| `state.record-session "" "Completed 19-04-PLAN.md" "None"` | `{"recorded":true, updated:["Last session","Resume File"]}` — **the dangerous one: it reports success while silently dropping `Stopped At`** |

Correct forms, confirmed working: `--phase --plan --duration --tasks --files`, `--summary [--rationale]
[--phase]`, `--stopped-at --resume-file`.

**Why this matters beyond one plan.** The first two fail loudly and get caught. `record-session` returns
`recorded: true` with `Stopped At` missing from its `updated` list — an executor that does not read the
`updated` array will believe the session was recorded and leave `Stopped at:` pointing at the previous plan.

**Also observed:** `state.record-session` writes only the BODY field. The frontmatter `stopped_at:` is
brought into line by a separate `state.sync`, which the executor template does not call. Running
`state.sync` after `record-session` is what advanced frontmatter `stopped_at` to `Completed 19-04-PLAN.md`
here.

**Not actioned here:** the fix is to the GSD agent templates under `.claude/`, which currently carry an
unrelated uncommitted tooling self-update that this phase must not disturb.

## D-19-E — STATE.md frontmatter `percent` disagrees with its own sibling counters

Frontmatter reads `total_plans: 37`, `completed_plans: 34`, `percent: 71`, while the body's bar reads
`[█████████░] 92%` — and 34/37 is 92%, not 71%. `percent: 71` has not moved since the Phase 18 close; every
plan from 19-01 onward left it. `state.update-progress` maintains the body bar and `completed_plans` but not
`percent`.

**Not a drift by the SDK's own reckoning:** `gsd-sdk query state.validate` returns
`{"valid": true, "warnings": [], "drift": {}}` against exactly this file, so the two fields are evidently not
expected to track each other — `percent` may be milestone-scoped by design. Recorded as an observation to be
resolved rather than as a confirmed defect, and deliberately **not** hand-edited.
