
## Deferred (logged 2026-09-11 during 16-01 execution)

- Untracked planning artifacts in the outer repo, created by earlier planning agents and outside this plan's file scope: `.planning/phases/16-sca-ecosystem-coverage/16-PATTERNS.md`, `.planning/phases/16-sca-ecosystem-coverage/16-PLAN-CHECK.md`, `.planning/phases/15-five-parallel-scan-jobs/15-VERIFICATION.md`. Not committed by 16-01 (scope boundary); 16-PATTERNS.md in particular is referenced as plan context and should be tracked.

## Deferred (logged 2026-09-11 during 16-02 execution)

- `repos/security-platform/fixtures/README.md` rewording carried forward by 16-01 ("pip-audit counts an
  advisory per source" -> the verified "46 entries = 23 unique advisories reported twice each; the 10
  unique IDs on the direct pins match Trivy's 10 exactly"). Not done here: `fixtures/README.md` is not in
  16-02's `files_modified`, and folding it into this commit would have mixed a docs edit into a commit
  whose acceptance criterion pins the `git log -1` subject. 16-03 commits to the same repo next and
  should absorb it.
