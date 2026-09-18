---
phase: 23-nexus-generic-chart
plan: 02
subsystem: infra
tags: [nexus, helm, docker, kind, smoke-test, eula, idempotency, shellcheck, live-evidence]

# Dependency graph
requires:
  - phase: 23-nexus-generic-chart
    plan: 01
    provides: "feature/phase-23-nexus-generic-chart branch, the render() wrapper shape, and the vacuous-pass SKIP convention"
  - phase: 15-ci-scan-jobs
    provides: "scripts/smoke-scans.sh — the live-smoke CONTRACT (temp-dir + cleanup trap, FAILURES/SKIPPED accumulators with the skip-is-not-a-pass doctrine, require_success, hard/soft preflight tiers, counted terminal summary)"
provides:
  - "scripts/nexus-live-smoke.sh — the live half of the phase evidence: docker two-pass provisioning idempotency, post-EULA artifact download with a size assertion, and a kind install smoke"
  - "BINDING CONTRACT on 23-04: the provisioning Job must carry label app.kubernetes.io/instance={{ .Release.Name }} and must NOT use a hook-succeeded delete-policy"
  - "BINDING CONTRACT on 23-03/23-04: the repo-body ConfigMap name must end '-repos'; the admin Secret key must be 'password'"
affects: [23-03, 23-04, 23-05, 23-06, 23-07, 23-08, phase-24-nexus-hardening]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Live smoke that reads its own inputs out of the chart (image from the rendered StatefulSet, repo bodies from the rendered ConfigMap) so the test cannot drift from what ships"
    - "Size-threshold assertion as the discriminator when the failure body is itself a well-formed HTTP response (Nexus CE EULA 403 is ~192 bytes; a real tarball is ~319 KB)"
    - "Three-state terminal verdict — FAILED / NOTHING RAN / ALL PASS — so zero failures on a run where zero checks executed can never print ALL PASS"
    - "Anti-vacuity guard before `kubectl wait`: count the matching resources first, because `kubectl wait` against an empty set is not a reliable exit-code signal"
    - "Environment restoration in the cleanup trap: `kind delete cluster` leaves the operator's kubeconfig current-context unset"

key-files:
  created:
    - repos/security-platform/scripts/nexus-live-smoke.sh
  modified: []

key-decisions:
  - "The terminal verdict is three-state, not two. smoke-scans.sh prints ALL PASS whenever FAILURES is empty; copied verbatim that would print ALL PASS on the skip path, which the plan's own acceptance criteria forbid. print_summary therefore prints `NOTHING RAN - 0 live check(s) executed` when CHECKS_PASSED is 0, and exits 0."
  - "The admin credential is passed to docker through a mode-600 env file and to kubectl through stdin, never on an argv. The plan specified `-e` and `--from-literal`; both would expose the credential to any local process reading /proc or `ps`, and `--from-literal=password=\"$NEXUS_PASSWORD\"` also trips the plan's own no-literal-credential grep via the substring PASSWORD."
  - "Every kubectl/helm call in the kind section pins --context/--kube-context explicitly. Without it a failed `kind create cluster` would silently redirect namespace creation, Secret application and `helm install` at whatever cluster the operator currently has selected."
  - "requirements.mark-complete was deliberately NOT invoked. NEXUS-01 is in this plan's frontmatter, but this plan builds the assertion, not the thing asserted — the chart and provision.sh that satisfy NEXUS-01 ship in 23-03/23-04. Follows the 23-01, 19-01..19-04 and 17-01 precedent recorded in STATE.md."

patterns-established:
  - "Prove-the-guard-fires for a LIVE gate: eleven execution paths (full green, eight single-defect mutations, two FATAL preflight tiers) driven against a scratchpad fake chart with real docker containers and two real kind clusters, before the subject exists"

requirements-completed: []

# Metrics
duration: 55min
completed: 2026-09-18
---

# Phase 23 Plan 02: Live Smoke — Docker Two-Pass and Kind Install Summary

**A 408-line live gate now boots a real container from the image the chart itself renders, runs the chart's own provisioning script twice, measures the downloaded tarball's size rather than trusting its status code, and installs the chart on a throwaway kind cluster — every path of it driven green, red and discriminating against a scratchpad fake chart before the real chart exists.**

## Performance

- **Duration:** ~55 min (two real kind cluster lifecycles at ~2m20s each dominate)
- **Started:** 2026-09-18T12:15:00Z (approx.)
- **Completed:** 2026-09-18T13:10:00Z (approx.)
- **Tasks:** 2 of 2
- **Files modified:** 1 (1 created) — in `repos/security-platform`

## Accomplishments

- **Built the only check that would catch the phase's headline defect.** Research measured that a pre-EULA Nexus CE deploys green, shows four correctly configured proxy repos, and serves metadata with HTTP 200 while returning a 192-byte 403 on every package download. `ARTIFACT-SIZE` is the assertion that separates those two worlds; a bare `curl -f` or a status-only check would not.
- **Built the only check that would catch a non-idempotent provisioner.** A repeat blind POST to the repositories API returns 400, so `PROVISION-PASS-2` exiting 0 is the only proof the `GET -> PUT/POST` upsert is real. Verified the check discriminates: a stub that succeeds once and exits 1 on the second run was reported as `PROVISION-PASS-2: exit=1 (FAIL)`.
- **Built an anti-vacuity guard on the kind half and proved it fires.** Installing a chart whose Job carries `hook-delete-policy: ...,hook-succeeded` produced a fully green `helm install` with nothing left to wait on. The guard reported `KIND-JOB-COMPLETE: FAIL - no Job matched ...`, exit 1 — a green install was correctly refused as evidence.
- **Found and fixed a real environment-damaging side effect** (see Deviations): the first full kind run left the operator's kubeconfig with `current-context is not set`.

## Task Commits

1. **Task 1: Docker two-pass idempotency and post-EULA artifact download** — `867c963` (test)
2. **Task 2: Add the kind install smoke section** — `e0b23b1` (test)

Branch: `feature/phase-23-nexus-generic-chart` on `repos/security-platform`, **unpushed** (23-08 owns push/PR/merge). Working tree clean.

## Files Created/Modified

- `repos/security-platform/scripts/nexus-live-smoke.sh` (new, 408 lines, git mode `100644` — not executable) — six sections: boot Nexus, extract repo bodies from the chart, provision pass 1, provision pass 2, post-EULA artifact download, kind install smoke.

## Verification Evidence

The script prints `SKIPPED` and exits 0 at this commit, so committing it unexercised would have shipped 408 unverified lines. A throwaway chart was built **in the scratchpad, never inside the repo** — the script anchors to `dirname $0/..`, so placing a copy at `<scratch>/scripts/` made `<scratch>` the repo root and left `security-platform` untouched. Sections 1-5 were driven against real `docker run` containers; section 6 against two real `kind` clusters.

### Green path — every section, all eight checks

Fake chart pointed at a purpose-built image serving a 200,000-byte file at the lodash path:

```
==> NEXUS-BOOT: PASS - container is running
==> REPO-BODY-COUNT: PASS - 4 repo body files written to $OUT/config
==> REPO-BODY-JSON: PASS - every extracted repo body parses as JSON
==> PROVISION-PASS-1: exit=0 (PASS)
==> PROVISION-PASS-2: exit=0 (PASS)
==> ARTIFACT-TRANSPORT: PASS
==> ARTIFACT-HTTP-200: PASS - tarball request returned HTTP 200
==> ARTIFACT-SIZE: PASS - 200000 bytes downloaded (> 100000)
ALL PASS - 8 live check(s) executed and passed; 0 sub-check(s) skipped
EXIT=0    (and `docker ps -a --filter name=nexus-live-smoke` -> 0 rows)
```

A separate full run added section 6 green against a real cluster: `KIND-CLUSTER`, `KIND-DEPENDENCY-BUILD`, `KIND-INSTALL` (`helm install ... --wait --timeout 15m` -> `STATUS: deployed`), `1 Job(s) still present after install`, `KIND-JOB-COMPLETE: job.batch/t-provision condition met`. Total wall time 2m20s.

### Single-defect mutations — each fired exactly one check, no spurious others

| # | Mutation | Check that fired | Observed |
|---|---|---|---|
| M1 | tarball absent from the server | `ARTIFACT-HTTP-200` + `ARTIFACT-SIZE` | HTTP 404, 460 bytes — both fired independently, as specified |
| M2 | nothing listening on 8081 | `ARTIFACT-TRANSPORT` (+ the two above) | `curl exited 52`; **`set -e` did not abort** — the `\|\| curl_rc=$?` guard held |
| M3 | chart renders only 3 repo bodies | `REPO-BODY-COUNT` | `expected 4 ... got 3` |
| M4 | one body is not JSON | `REPO-BODY-JSON` | `do not parse as JSON: 001-pypi.json` |
| M5 | ConfigMap name no longer ends `-repos` | `REPO-BODY-EXTRACT` | named abort; provisioning correctly not attempted |
| M6 | provision.sh exits 1 on the second run | `PROVISION-PASS-2` only | pass 1 PASS, pass 2 `exit=1 (FAIL)` — the idempotency discriminator works |
| M9 | chart renders two StatefulSets | `NEXUS-IMAGE` | ambiguous image refused rather than `head -n1`'d |
| M11 | Job carries `hook-delete-policy: ...,hook-succeeded` | `KIND-JOB-COMPLETE` | green `helm install`, **empty Job set reported as FAIL**, exit 1 |

### Preflight and skip paths

| Path | Observed |
|---|---|
| `PATH=/usr/bin:/bin` | `FATAL: required binary 'docker' not found on PATH`, exit 1 |
| `PATH=/usr/bin:/bin:/usr/local/bin` | `FATAL: required binary 'yq' ...`, exit 1 (this macOS ships `/usr/bin/jq`, the 23-01 lesson) |
| full PATH minus `helm` | `FATAL: required binary 'helm' ...`, exit 1 |
| no `charts/*.tgz` | `FATAL: subchart not vendored — run: helm dependency build kubernetes/nexus`, exit 1 |
| **`provision.sh` absent AND no `charts/*.tgz`** | `SKIPPED ... provision.sh does not exist yet`, exit 0, **no FATAL** — proves the ordering the plan required |
| `kind`/`kubectl` off PATH (M10) | section 6 `SKIPPED`, accounted separately; exit status driven only by real failures |
| real repo, this commit | `SKIPPED - 1 sub-check(s) ... A SKIP IS NOT A PASS` + `NOTHING RAN - 0 live check(s) executed`, exit 0, **no `ALL PASS`** |

### Static acceptance criteria (both tasks)

`shellcheck` exit 0; `bash -n` exit 0; `pre-commit run --all-files` exit 0; git mode `100644` (`test ! -x` succeeds); credential grep `grep -vE '^\s*#' | grep -c 'admin123\|password=.*[A-Za-z0-9]\{8\}'` = **0**; `grep -c '3\.96\.0'` = **0**; present: `head -c 24 /dev/urandom`, `docker rm -f` on the `trap` line, `PROVISION-PASS-1`, `PROVISION-PASS-2`, `lodash-4.17.21.tgz`, `100000`, `REPO_CONFIG_DIR`, `EULA_ACCEPTED`, `kind create cluster`, `kind delete cluster` (on the trap line), `--timeout 15m`, `condition=complete`, `KIND-INSTALL`, `KIND-JOB-COMPLETE`, `--set nexus3.rootPassword.secret=nexus-admin`, `--set eula.accepted=true`, `--set repos.helm.remoteUrl=`. Both `must_haves` key_links present: `helm template ... kubernetes/nexus` and `kubernetes/nexus/files/provision.sh`.

`bash scripts/check-nexus-chart.sh` still exits 0 (`SKIP: chart not present yet`) — no regression on the 23-01 gate.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Missing critical functionality] The kind section damaged the operator's kubeconfig**

- **Found during:** Task 2 verification (first full kind run)
- **Issue:** `kind create cluster` rewrites the kubeconfig `current-context`, and `kind delete cluster` then leaves it **unset**. Measured after a clean, fully green run: `kubectl config current-context` -> `error: current-context is not set`. The operator's own cluster selection was silently destroyed by a test.
- **Fix:** `KUBECTX_BEFORE` is captured immediately before `kind create cluster` and restored by the cleanup trap on every exit path.
- **Files modified:** `repos/security-platform/scripts/nexus-live-smoke.sh`
- **Commit:** `e0b23b1`
- **Re-verified:** context `admin@occ-new` before the run, `admin@occ-new` after it, cluster deleted.

### Divergences from the plan text (deliberate, with reasons)

**1. The terminal verdict is three-state, not the two-state block from `smoke-scans.sh`.**
The plan asks for the summary block "copied verbatim in shape" *and* for the skip path to exit 0 without printing `ALL PASS`. Those are incompatible: `smoke-scans.sh`'s `else` branch prints `ALL PASS` whenever `FAILURES` is empty, which on the skip path is a vacuous green. `print_summary` therefore has a third branch — `CHECKS_PASSED == 0` prints `NOTHING RAN - 0 live check(s) executed; N sub-check(s) skipped (not passed). Nothing was proven.` and exits 0. The SKIPPED heading, the `A SKIP IS NOT A PASS` doctrine line, the failure loop and the exit codes are otherwise identical in shape.

**2. The credential never appears on an argv.**
The plan specified `-e NEXUS_SECURITY_INITIAL_PASSWORD=...` on `docker run` and `kubectl create secret ... --from-literal=password="$NEXUS_PASSWORD"`. Both put the generated admin password in a process argument list, readable by any local process — a weaker position than T-23-06 requires. Replaced with a mode-600 `--env-file` inside the trap-cleaned temp dir, and `kubectl apply -f -` from a `stringData` heredoc. The second form is also what keeps the plan's own no-literal-credential grep at 0: `--from-literal=password="$NEXUS_PASSWORD"` matches `password=.*[A-Za-z0-9]\{8\}` through the substring `PASSWORD`. Task 2's acceptance criteria do not pin `--from-literal`.

**3. Explicit `--context` / `--kube-context` on every kubectl and helm call in section 6.**
Not in the plan. Without it, a failed `kind create cluster` leaves the subsequent `kubectl create namespace`, Secret apply and `helm install` pointed at the operator's currently selected cluster. A test must not be able to install a chart on a real cluster by accident.

**4. Two checks added beyond the plan's list: `KIND-CLUSTER` and `KIND-DEPENDENCY-BUILD`.**
The plan's sequence includes `kind create cluster` and `helm dependency build` as steps but only labels the install and the wait. Unlabelled steps would have aborted the script under `set -e` with no entry in the summary. Both are now scored, so a cluster that fails to come up is a named failure rather than a silent crash.

**5. `requirements.mark-complete` deliberately not invoked; `requirements-completed: []`.**
`NEXUS-01` is in the plan frontmatter, but nothing in this plan configures a proxy repository — it builds the test that will prove 23-04 did. Marking it here would repeat the 17-01 mistake recorded in STATE.md. Read `[]` as **withheld on purpose**.

## Observations Handed Forward

1. **Three binding contracts this smoke now imposes on 23-03/23-04.** They are assertions, so violating them shows up as a red check, not a silent drift:
   - the provisioning Job must carry `app.kubernetes.io/instance: {{ .Release.Name }}` as a **label**, or `KIND-JOB-COMPLETE` reports an empty Job set;
   - the Job's `helm.sh/hook-delete-policy` must **not** include `hook-succeeded` (measured: it deletes the Job and leaves nothing to wait on);
   - the repo-body ConfigMap's name must end `-repos`, and the admin Secret's key must be `password`.
2. **`helm dependency build` hits the network in helm v4.** Observed output: `Hang tight while we grab the latest from your chart repositories...` followed by a full repo index refresh, including one unrelated 404 (`kubernetes-dashboard`) that did **not** fail the command. CI wiring for section 6 needs network and tolerance for a slow index refresh.
3. **`curl` exit 52 would have killed the script.** `code=$(curl ...)` under `set -euo pipefail` aborts on any transport error; the `|| curl_rc=$?` guard is load-bearing, not defensive decoration. Measured against a container with no listener on 8081.
4. **`yq` v4.53.6 here unwraps scalars** (`image: "a:b"` -> `a:b`), contrary to the caution recorded in 23-01. The `unquote` helper is retained anyway because CI may run a different yq.
5. **The kind half costs ~2m20s per run** on this hardware with images warm — well inside the 15m Helm timeout, but the timeout must not be reduced: that measurement is for a `nginx:alpine` placeholder, not for Nexus first boot, which research sized at 1-3 minutes on homelab hardware on top of the install.
6. **Section 5 cannot pass until 23-04 lands**, by construction — it needs a provisioner that actually accepts the EULA and creates `npm-proxy`. 23-06 is the plan that runs this script for real and turns `NOTHING RAN` into `ALL PASS`.

## Threat Model Coverage

| Threat ID | Disposition | How this plan mitigates it | Status |
|---|---|---|---|
| T-23-02 | mitigate | Password generated at runtime from `/dev/urandom`, never echoed, never committed; passed via a mode-600 env file (docker) and stdin (kubectl), never an argv. Credential grep measured 0. | ✅ implemented + measured |
| T-23-06 | mitigate | No `set -x` anywhere; `curl -sS -o <file> -w '%{http_code}'`; the Secret value is never printed; `require_success` echoes the label and exit code only, never `"$@"`. | ✅ implemented + measured |
| T-23-05 | accept | The smoke sets `EULA_ACCEPTED=true` on an ephemeral throwaway container/cluster only; the shipped chart default stays `false` (D-09). | ✅ as designed |
| T-23-01 | mitigate | Cleanup trap runs `docker rm -f` and `kind delete cluster` on every exit path. Measured: 0 leaked containers and 0 kind clusters after green, red and FATAL runs. | ✅ implemented + measured |
| T-23-SC | mitigate | No package-manager install in this plan; the container image is resolved out of the chart's own rendered output rather than hardcoded. | ✅ n/a by construction |

## Known Stubs

None. The `SKIPPED` guards are the documented vacuous-pass convention inherited from 23-01, not placeholders; 23-06 is the plan that closes them by running this script against the real chart.

## Threat Flags

None. The script opens no new persistent endpoint and adds no auth path to the product — it authenticates to an ephemeral throwaway Nexus over loopback and performs one outbound fetch from `registry.npmjs.org` through it, both already in the register's trust boundaries. The one side effect that touched state outside the test (kubeconfig `current-context`) was found, fixed and re-verified rather than documented and left.

## Self-Check: PASSED

- `repos/security-platform/scripts/nexus-live-smoke.sh` — FOUND (408 lines, git mode `100644`)
- Commit `867c963` — FOUND on `feature/phase-23-nexus-generic-chart`
- Commit `e0b23b1` — FOUND on `feature/phase-23-nexus-generic-chart`
- Branch `feature/phase-23-nexus-generic-chart` — current, working tree clean, unpushed
- `bash scripts/nexus-live-smoke.sh` — exit 0, prints `SKIPPED` naming `provision.sh`, no `ALL PASS`, no `FATAL`
- `bash scripts/check-nexus-chart.sh` — exit 0 (no regression)
