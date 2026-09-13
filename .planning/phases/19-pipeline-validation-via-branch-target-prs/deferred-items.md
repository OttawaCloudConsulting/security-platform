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

## D-19-C — pre-commit Gitleaks hook is structurally a no-op (carried from 19-02 Handoff Note 7)

`stages: [pre-push]` + an entry of `gitleaks git --pre-commit --redact --staged --verbose` means the hook
never runs at commit and scans an empty staged diff at push. Re-confirmed at push scope in 19-03 by invoking
the installed `.git/hooks/pre-push` with git's exact stdin line: rc=0, `Detect hardcoded secrets ... Passed`.

**Not actioned here:** CONTEXT forbids config changes in this phase. Fix options remain as 19-02 recorded:
move to `stages: [pre-commit]` so `--staged` is meaningful, or change the entry to a history scan.
