---
phase: 25-nexus-live-validation
plan: 01
subsystem: security-platform / live validation gate
tags: [nexus, argocd, bash-gate, live-validation, anonymous-access, docker-registry]
requires: []
provides:
  - "security-platform scripts/nexus-homelab-validate.sh — --url/--context/--sync-pass parameterised live gate (4 cluster-side labels + 11 protocol labels)"
  - "security-platform branch feature/phase-25-nexus-live-validation (branched from origin/main aed14b9), which plan 25-06 ships from"
affects: [25-02, 25-03, 25-04, 25-05, 25-06, 25-07]
tech-stack:
  added: []
  patterns:
    - "FAILURES / SKIPPED / CHECKS_PASSED accounting with a three-branch summary (FAILED / NOTHING RAN / ALL PASS), lifted verbatim from nexus-live-smoke.sh"
    - "Every failable command captured with `|| rc=$?` into an explicit verdict, so a bad context or unreachable URL reaches print_summary instead of dying under set -e"
    - "Every kubectl invocation pins --context on the same line; the current context is never assumed"
key-files:
  created:
    - repos/security-platform/scripts/nexus-homelab-validate.sh
  modified: []
decisions:
  - "Gate requires --url and owns no port-forward; sibling of nexus-live-smoke.sh, not an in-place parameterisation (both forks recorded in the script header)"
  - "Realms reads (DOCKER-REALM-ACTIVE, SECOND-SYNC-IDEMPOTENT) try unauthenticated first as planned, and fall back to admin only on 401/403. The pass message records which identity read the list"
  - "DOCKER-PATH-SHAPE correct-shape leg asserts exactly 200 (as in the analog and 25-RESEARCH §6), stricter than the plan's 'must not 404'"
  - "ANONYMOUS-WRITE-DENIED emits no pass when the instrument cannot run (kubectl absent: named SKIP; secret unreadable: fail). A 403 alone is not the whole claim"
metrics:
  duration: "~35 min"
  completed: 2026-09-23
  tasks: 3
  files: 1
---

# Phase 25 Plan 01: nexus-homelab-validate.sh live gate Summary

Added `scripts/nexus-homelab-validate.sh` (1130 lines, mode 644) to `security-platform`. It is a `--url`/`--context`/`--sync-pass` parameterised sibling of `nexus-live-smoke.sh`. It reads the Argo CD hook phase, the provisioning Job's log token count and the PVC's measured default StorageClass. It also runs the nine anonymous-pull verdicts, the Docker realms, path-shape and five-leg Bearer handshake, the exactly-403 write refusal with its instrument and readback, and the second-sync idempotency assertion. It prints `NOTHING RAN` rather than `ALL PASS` when nothing executed.

## Commits

| Task | Repo | Commit | Description |
|------|------|--------|-------------|
| 1-3 | security-platform (branch `feature/phase-25-nexus-live-validation`) | `2c76632` | feat(25-01): add nexus-homelab-validate.sh live gate |

The plan put a single `security-platform` commit in Task 3's verify step, so Tasks 1 and 2 have no separate commits. That was the plan's instruction, not a deviation. Nothing was committed to this docs repo for Tasks 1–3 because `repos/security-platform` is gitignored here (confirmed with `git check-ignore`). Nothing was pushed and no PR was opened.

## Verification (observed)

- `bash -n` exit 0, and `shellcheck -S warning` exit 0 with no output. The shellcheck pre-commit hook also passed at commit time.
- `--help` exit 0, and its output contains `--sync-pass`.
- No args: exit 2, and stderr names `--url`. With `--url … --context ctx` but no `--sync-pass`: exit 2, and stderr names `--sync-pass`. `--sync-pass third`: exit 2. Unknown arg: exit 2.
- `test ! -x` holds (mode 644).
- The kubectl-invocation grep from the acceptance criteria returns no lines.
- `set -x` count is 0 outside comments. No `echo`/`printf` line contains `NEXUS_PW`. The only non-comment `|| true` is the EXIT trap line.
- `DOCKER_BLOB_MIN_BYTES=1000000` appears once. Each of the three byte-floor constants appears once, and the PyPI trailing-slash URL appears once. `DOCKER_MANIFEST_URL_WRONG` appears 4 times.
- `--url http://127.0.0.1:1 --context does-not-exist` with `--sync-pass first`: prints `FAILED`, exit 1, never `ALL PASS`. The same with `second`: `FAILED`, exit 1.
- With kubectl removed from PATH: all cluster-side checks become named SKIPs, and the HTTP checks still run and report `FAILED`.
- The jq expressions for the hook filter, the ConfigMap `000-npm.json` name extraction, the default StorageClass and realms normalisation were each checked against sample JSON and gave the expected values.
- Plan-level: `bash scripts/check-nexus-chart.sh` gives PASS, 18 checks. `git status --short scripts/nexus-live-smoke.sh` is empty.
- `git show --stat HEAD` lists only `scripts/nexus-homelab-validate.sh`.

**Not verified:** no check has been run against a live Nexus. The homelab has no `nexus` namespace or Application yet (checked with `kubectl --context admin@occ-new`). Every pass path is unexercised until plan 25-05/25-07 runs the gate live.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Realms reads fall back to admin on 401/403**
- **Found during:** Task 2
- **Issue:** The plan (and 25-RESEARCH §8) reads `/service/rest/v1/security/realms/active` unauthenticated. The analog (`nexus-live-smoke.sh`) always reads it as admin. The realms list is a security setting, and Nexus's anonymous role may be refused it. If so, both DOCKER-REALM-ACTIVE and SECOND-SYNC-IDEMPOTENT would go permanently red for a reason unrelated to the realms list. This is unmeasured: there is no live instance to check against.
- **Fix:** The unauthenticated GET runs first. Only on HTTP 401/403, and only with the admin password available from Secret `nexus-admin`, is the same GET repeated as admin. The identity used is recorded in every verdict message.
- **Files modified:** scripts/nexus-homelab-validate.sh
- **Commit:** 2c76632

**2. [Rule 1 - Bug] DOCKER-PATH-SHAPE correct-shape leg asserts exactly 200**
- **Found during:** Task 2
- **Issue:** The plan says the correct shape "must not 404". That would let a 5xx or 401 pass as "routes".
- **Fix:** The leg asserts exactly 200, matching the analog and the measured value in 25-RESEARCH §6. The wrong-shape leg still asserts exactly 404.
- **Commit:** 2c76632

**3. [Rule 2 - Correctness] Failure paths reach `print_summary` instead of dying under `set -e`**
- **Found during:** Task 1
- **Issue:** A bare `$(kubectl …)`, `grep -c` or `jq` on an unwritten file would kill the run before the verdict when the context is wrong or the URL is unreachable.
- **Fix:** Every such command is captured into an rc or count variable (`|| rc=$?`, `|| count=0`). PROVISION-JOB-COMPLETE tells a kubectl error apart from a NotFound Job. A failed `kubectl logs` deletes the partial log so that SECOND-SYNC reads "no log" rather than an empty log.
- **Commit:** 2c76632

### Other notes
- The Secret `nexus-admin` is read once, into `NEXUS_PW`, right after the cluster checks rather than inside ANONYMOUS-WRITE-DENIED. The realms admin fallback also needs it. It is still read only via kubectl, never echoed and never put on argv except as curl `-u`, as the plan specifies.
- The upstream npm name and version are also env-overridable (`NEXUS_VERIFY_NPM_NAME` / `NEXUS_VERIFY_NPM_VERSION`), in addition to the PyPI project and the Docker path and tag. The defaults keep the plan's `lodash-4.17.21` URL.
- The `anon-write-probe` literal appears once, as `ANON_WRITE_REPO`. The POST body (`jq --arg name "$ANON_WRITE_REPO"`) and the 404 readback URL both use that variable.

## Requirements note

The plan frontmatter lists `NEXUS-05`. This plan is the Wave 0 instrument only: NEXUS-05 is closed by live evidence in later plans (25-05 / 25-07), not by this script existing. For that reason `requirements.mark-complete NEXUS-05` was deliberately NOT run, and REQUIREMENTS.md is unchanged. The requirement should be checked off by the plan that produces the live evidence.

## Known Stubs

None.

## Threat Flags

None. The only new surface is the planned one: a kubectl Secret read (T-25-02) and an anonymous POST probe (T-25-01), both mitigated as the threat model requires. No host, password or VIP literal is in the file.

## Self-Check: PASSED
- FOUND: repos/security-platform/scripts/nexus-homelab-validate.sh
- FOUND: 2c76632 on feature/phase-25-nexus-live-validation in repos/security-platform
