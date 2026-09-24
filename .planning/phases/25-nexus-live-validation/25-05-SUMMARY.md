---
phase: 25-nexus-live-validation
plan: 05
subsystem: homelab Argo CD second sync, idempotency gate, workstation routing, chart-edit decision
tags: [nexus, argocd, idempotency, second-sync, workstation, nexus-setup, hook-semantics, homelab]
requires:
  - "25-01: scripts/nexus-homelab-validate.sh --sync-pass second (security-platform branch feature/phase-25-nexus-live-validation)"
  - "25-04: live Application nexus Synced+Healthy, first-sync evidence on disk"
provides:
  - "A measured second sync against a PVC that already held state: 4x action=updated, 0x action=created, realms no-change path"
  - "A second-pass gate with ALL PASS over 18 checks, including SECOND-SYNC-IDEMPOTENT"
  - "The workstation routing script's verdicts against the live homelab Nexus: npm ok, pip ok, helm ok, docker MANUAL"
  - "The verdict on 25-RESEARCH Open Question 3: NO CHART EDIT NEEDED, which plan 25-06 executes"
affects: [25-06, 25-07]
tech-stack:
  added: []
  patterns:
    - "Record the hook Job's UID before a sync. A new UID under the same name afterwards is direct evidence of BeforeHookCreation delete-then-create"
    - "Run workstation/nexus-setup.sh --verify from a throwaway git init repo seeded with package.json. Its configure step writes into the git toplevel of the cwd"
key-files:
  created:
    - .planning/phases/25-nexus-live-validation/evidence/25-05-second-sync-provision.log
    - .planning/phases/25-nexus-live-validation/evidence/25-05-homelab-validate-second.txt
    - .planning/phases/25-nexus-live-validation/evidence/25-05-nexus-setup-verify.txt
    - .planning/phases/25-nexus-live-validation/evidence/25-05-docker-daemon.sha256
    - .planning/phases/25-nexus-live-validation/evidence/25-05-chart-edit-assessment.md
  modified: []
decisions:
  - "Open Question 3 is closed as NO CHART EDIT NEEDED. hookType was Sync on both syncs, BeforeHookCreation was measured (new Job UID, no immutable error), and the 900s TTL truncated nothing (logs captured 9s and 4s after completion). Plan 25-06 leaves job-provision.yaml unchanged"
  - "nexus-setup.sh --verify is not read-only: it runs the configure writers first. It was run from a throwaway git repo so that no .npmrc, pip.conf, .nexus-env or .helm was written into either real repository"
metrics:
  duration: "~10 min"
  completed: 2026-09-24
  tasks: 3
  files: 5
---

# Phase 25 Plan 05: Second sync, idempotency and chart-edit decision Summary

A second Argo CD sync re-ran the provisioning hook against a Nexus whose PVC already held state. It upserted all four repositories as updates, left the realms list untouched, and the second-pass gate printed `ALL PASS` over 18 checks, with `SECOND-SYNC-IDEMPOTENT` passing. This closes ADR-021 `What was NOT verified` item 7 by measurement. The workstation routing script measured npm, pip and Helm routing as `ok` against the live instance; Docker is `MANUAL` by design. Open Question 3 is closed as **NO CHART EDIT NEEDED**.

## Correction to the orchestrator brief

The brief said the first-sync Job was "already gone". It was not. At 01:09:43Z `job/nexus-provision` (UID `11400922-1baf-48c3-a1e0-a63ed45aa332`, completed 01:04:55Z) was still present, inside its 900 s TTL. The second sync deleted it, not the TTL reaper. That turned out to be useful evidence for Task 3 Q2.

## Task 1: second sync and idempotency

- **Precondition:** `25-04-first-sync-provision.log` was on disk, 2329 bytes.
- **Trigger** (01:12:24Z): `kubectl --context admin@occ-new -n argocd patch applications.argoproj.io nexus --type merge -p '{"operation":{"initiatedBy":{"username":"phase-25"},"sync":{}}}'`, with no `revision`.
- **Operation:** `startedAt 2026-09-24T01:12:25Z`, compared with `01:03:06Z` for the first sync, so this was a separate operation. `finishedAt 01:12:32Z`, phase `Succeeded`, message `successfully synced (no more tasks)`. The recorded `initiatedBy` is `{"automated":true,"username":"phase-25"}`, verbatim from the Application status. The revisions did not change (`aed14b9…` chart, `a05471b…` overlay). The hook entry is `hookType: Sync, hookPhase: Succeeded`. No sync-result resource had a status other than `Synced`.
- **New Job:** UID `f3c25405-d448-4fe9-b429-58b532c84eae`, created 01:12:28Z, completed 01:12:32Z. The log was captured at 01:12:36Z. Nexus was already up, so the readiness wait passed on its first probe.
- **Log, compared with the first pass.** Literal lines from `25-05-second-sync-provision.log`:
  - `repo: format=npm name=npm-proxy action=updated (HTTP 204)`, and the same for pypi-proxy, docker-proxy and helm-proxy. That is **4** `action=updated` and **0** `action=created`. The first pass had 4 `action=created (HTTP 201)`.
  - `anonymous: OPEN (HTTP 200) — unauthenticated READ is now allowed across every repository on this instance, as user 'anonymous' via realm 'NexusAuthorizingRealm'. Idempotent: a re-run returns 200 again.`, which is byte-identical to the first pass.
  - `realms: DockerToken already active — no change, and no request was made.`, the guarded no-change path (`files/provision.sh:313`). The first pass had `realms: appended DockerToken (HTTP 204)`.
  - `EULA: accepted (HTTP 204)`, the same as the first pass.
- **Gate** (`--sync-pass second`, exit 0): `ALL PASS - 18 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).` The first pass had 17 passes plus the `SECOND-SYNC-IDEMPOTENT` skip.
  - `SECOND-SYNC-IDEMPOTENT: PASS`: 4x updated, 0x created, the no-change realms line, and active realms exactly `["NexusAuthenticatingRealm","DockerToken"]` after `jq -c`. The realms were read as admin because the anonymous read returned 403, the same as in 25-04.
  - All nine anonymous-pull verdicts were still green, with the same sizes as the first pass: npm 318961, PyPI 76776, Helm 291818.
  - `DOCKER-REALM-ACTIVE`, `DOCKER-PATH-SHAPE` (200/404), `ANONYMOUS-PULL-DOCKER` (3626020-byte layer) and `ANONYMOUS-WRITE-DENIED` (unauthenticated POST 403, probe 404) were all green.
- **Port-forward:** ready after 2 polls. After the kill, the PID was gone and `curl` returned rc=7.

## Task 2: workstation routing verdicts (NEXUS-04, non-blocking)

- **daemon.json** (`25-05-docker-daemon.sha256`): `before 27369c832f1be7d067b379f3236a203993e7bec45135e58829a9273c3209f53c` and `after 27369c832f1be7d067b379f3236a203993e7bec45135e58829a9273c3209f53c`, so the two are equal. The file existed before this run and was not changed. `--docker-daemon` was not passed.
- **Command:** `bash repos/security-platform/workstation/nexus-setup.sh --verify --url http://127.0.0.1:8081`, run from a throwaway `git init` repo with a minimal `package.json` (see Deviations). Exit code 0.
- **Verdicts, verbatim from the script's table:** `Rows: 3 ok, 0 not ok, 1 MANUAL.`

| Ecosystem | Status | Measured |
|---|---|---|
| npm | ok | `npm pack lodash@4.17.21` pulled 318961 bytes through `.npmrc` with an empty cache |
| pip | ok | `Looking in indexes: http://127.0.0.1:8081/repository/pypi-proxy/simple`; downloaded `six-1.17.0-py2.py3-none-any.whl` with the cache disabled |
| helm | ok | `helm search repo -r nexus/` returned 12 chart rows from the repo-scoped config; the global `repositories.yaml` hash was unchanged |
| docker | MANUAL | `NEXUS_DOCKER_REGISTRY=127.0.0.1:8081/docker-proxy`. There is no per-repo mechanism, and the script itself says MANUAL is not a pass |

- **Classification.**
  - There is no red row, and there is no SKIPPED or UNVERIFIABLE row.
  - Docker `MANUAL` is neither an L-01 consequence nor a defect. It is by design (ADR-021 decision 7, daemon opt-in) and is **not** recorded as a pass.
  - The three `ok` rows were measured over plaintext loopback HTTP. TLS and hostname routing (L-01) remain unmeasured and go into ADR-022 `What was NOT verified`.
  - NEXUS-04's client-side routing for npm, pip and Helm is now confirmed against a long-lived cluster, not only the Phase 24 container.
- **No leakage.** No `.npmrc`, `pip.conf`, `.nexus-env` or `.helm` appeared in the docs repo or in `repos/security-platform`. `~/.npmrc` and the user pip configs are still absent, and the global Helm `repositories.yaml` sha256 did not change.

## Task 3: chart-edit assessment

`evidence/25-05-chart-edit-assessment.md` gives the verdict **NO CHART EDIT NEEDED**:

- **Q1:** `hookType: Sync` on both syncs.
- **Q2:** a new Job UID under the same name, the first Job still present before the sync, and no immutable error, so BeforeHookCreation delete-then-create applied.
- **Q3:** the log was captured 9 s after completion on sync 1 and 4 s on sync 2. On sync 2 the operation `finishedAt` equals the Job `completionTime`, so the TTL was never close to mattering.

Plan 25-06 makes no change to `kubernetes/nexus/templates/job-provision.yaml`. `ttlSecondsAfterFinished: 900` stays; it is a floor. The `security-platform` chart diff under `kubernetes/nexus/` is empty.

**Residual item for ADR-022:** the measurement cannot tell whether `BeforeHookCreation` came from Argo's no-policy default or from the mapped `helm.sh/hook-delete-policy`. Argo's helm.md says both "all Helm hooks will be ignored" and "`helm.sh/hook-delete-policy` Supported". Both routes give the observed behaviour.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `b62e893` | docs(25-05): second-sync idempotency evidence (ALL PASS, 18 checks) |
| 2 | `5604aaa` | docs(25-05): workstation routing verdicts against live homelab Nexus |
| 3 | `b1cfbe9` | docs(25-05): chart edit assessment - NO CHART EDIT NEEDED |

## Deviations from Plan

1. **[Rule 3 - Blocking] `nexus-setup.sh --verify` writes before it verifies.** The script runs `configure_npm`, `configure_pip`, `configure_helm`, `write_nexus_env` and `update_gitignore` unconditionally, targeting `git rev-parse --show-toplevel` of the cwd, and only then runs `run_verify`. Run from the docs repo, it would have written `.npmrc`, `pip.conf`, `.nexus-env` and `.helm/` there and appended to the tracked `.gitignore`. I ran it instead from a throwaway `git init` repo in the session scratchpad, seeded with a minimal `package.json`. Without that file, `verify_npm` returns UNVERIFIABLE by its own contract, which would be an artefact of the setup, not a finding. Paths in the evidence are scrubbed to `<throwaway-git-repo>` and `~`.
2. **The Task 2 automated verify's vocabulary grep (`PASS|FAIL|SKIP`) does not match this script's output.** The script's vocabulary is `ok`/`FAILED`/`SKIPPED`/`UNVERIFIABLE`/`MANUAL`, and an all-green run prints none of the grep's tokens. My first recorder header happened to contain `FAILED / SKIPPED`, which would have satisfied the grep vacuously. I reworded the header so that it does not. The substantive verdict line is `Rows: 3 ok, 0 not ok, 1 MANUAL.` The verify's other three conditions pass: the file is non-empty, there is no `--docker-daemon` invocation, and the sha256 values are equal.
3. **In-cluster service FQDN redacted** from the second-sync log's first line (`<nexus-service-fqdn>`), as in `58bc8ab`. Apart from that substitution, the file is identical to the raw capture (checked with `diff`).
4. **`.log` force-added** (`git add -f`) past the global `*.log` ignore, for the single planned evidence path.
5. **NEXUS-05 left unchecked in REQUIREMENTS.md.** Formal closure is plan 25-07. The same choice was made in 25-01 to 25-04.

## Evidence hygiene

- No admin password and no base64 credential appear in any file. The gate reads the password into a shell variable itself.
- `grep -nE '([0-9]{1,3}\.){3}[0-9]{1,3}' evidence/25-05-*` returns nothing other than `127.0.0.1`. `svc.cluster.local` does not appear.
- No other port-forward process is running: `pgrep -fl port-forward` is empty.

## Known Stubs

None.

## Threat Flags

None. T-25-24/25 were mitigated by the realms assertion, T-25-26 by the re-asserted write denial, T-25-27 by the unchanged sha256 and the unpassed flag, and T-25-28 by the no-vacuous-pass handling in Deviation 2. For T-25-29, loopback exposure was bounded to two single-invocation port-forwards.

## Self-Check: PASSED

- All five evidence files are tracked (`git ls-files --error-unmatch`)
- Commits `b62e893`, `5604aaa` and `b1cfbe9` exist, and none of them deletes a file
- Task 1 and Task 3 `<verify>` blocks printed `T1-VERIFY-OK` and `T3-VERIFY-OK`. For Task 2, the three substantive conditions passed; the vocabulary grep is covered in Deviation 2
- `repos/security-platform` working tree is clean, so no chart file was touched
