
## Deferred (logged 2026-09-11 during 16-01 execution)

- Untracked planning artifacts in the outer repo, created by earlier planning agents and outside this plan's file scope: `.planning/phases/16-sca-ecosystem-coverage/16-PATTERNS.md`, `.planning/phases/16-sca-ecosystem-coverage/16-PLAN-CHECK.md`, `.planning/phases/15-five-parallel-scan-jobs/15-VERIFICATION.md`. Not committed by 16-01 (scope boundary); 16-PATTERNS.md in particular is referenced as plan context and should be tracked.

## Deferred (logged 2026-09-11 during 16-02 execution)

- `repos/security-platform/fixtures/README.md` rewording carried forward by 16-01 ("pip-audit counts an
  advisory per source" -> the verified "46 entries = 23 unique advisories reported twice each; the 10
  unique IDs on the direct pins match Trivy's 10 exactly"). Not done here: `fixtures/README.md` is not in
  16-02's `files_modified`, and folding it into this commit would have mixed a docs edit into a commit
  whose acceptance criterion pins the `git log -1` subject. 16-03 commits to the same repo next and
  should absorb it.

## Resolved (2026-09-11, during 16-03 execution)

- `repos/security-platform/fixtures/README.md` rewording (carried from 16-01 via 16-02) — DONE in
  commit `6ae3019`, with the replacement text measured rather than inferred: 46 pip-audit entries =
  23 unique advisories, and the 10 unique advisories on the direct pins carry exactly Trivy's 10
  CVE ids as aliases (verified as an identical set).
- Still open: the untracked planning artifacts logged by 16-01 (`16-PATTERNS.md`,
  `16-PLAN-CHECK.md`, `15-VERIFICATION.md` in the outer repo).

## Deferred (logged 2026-09-11 during 16-06 execution)

- **Pre-existing broken relative link in the blueprint.** `docs/development-security-stack-option-1.md`
  line ~1427 links `[ADR-011](docs/adr/adr011-precommit-bypass-warning.md)`. Since the blueprint itself
  lives under `docs/`, that path resolves to `docs/docs/adr/…` and is broken — it dates from when the
  blueprint sat at the repo root (CLAUDE.md still describes it that way). 16-06's new note therefore uses
  the *working* path `adr/adr015-tflint-terraform-pin-checking.md` rather than copying the stale style.
  Fixing the ADR-011 link (and the CLAUDE.md path description) is out of 16-06's file scope — the plan's
  acceptance criteria pin this commit's contents, and a drive-by edit to unrelated prose would violate
  the executor scope boundary. A future docs-hygiene plan should sweep all relative links in the blueprint.
