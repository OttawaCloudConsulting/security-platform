---
phase: 24
slug: nexus-anonymous-access-and-workstation-script
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-19
finalised: 2026-09-20
finalised_against: "OttawaCloudConsulting/security-platform origin/main @ aed14b9 (merge of PR #15)"
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None conventional. `security-platform` has no pytest/jest/bats suite. Validation is two hand-written, hand-run gate scripts plus `pre-commit` — the established Phase 23 convention, extended here. |
| **Config file** | `security-platform/.pre-commit-config.yaml` (shellcheck, yamllint with `exclude: ^kubernetes/.*/templates/`, gitleaks) |
| **Quick run command** | `bash scripts/check-nexus-chart.sh` (17 checks today, 18 after plan 24-01) plus `bash scripts/check-nexus-setup.sh` (new in plan 24-03) — offline, seconds |
| **Full suite command** | `bash scripts/check-nexus-chart.sh && bash scripts/check-nexus-setup.sh && bash scripts/nexus-live-smoke.sh` — ~3 min docker half, ~8 min with kind half |
| **Estimated runtime** | ~10 seconds (quick) / ~11 minutes (full) |

Both scripts follow a **VACUOUS-PASS** convention — a run in which nothing executed prints `NOTHING RAN`, not `ALL PASS`; SKIP is never counted as a pass. Preserve this.

---

## Sampling Rate

- **After every task commit:** `bash scripts/check-nexus-chart.sh` + `pre-commit run --files <changed>`
- **After every plan wave:** full offline gate + `bash scripts/nexus-live-smoke.sh` docker half
- **Before `/gsd:verify-work`:** both gates green, `ALL PASS`, zero SKIPPED, and each newly added check proven non-vacuous by reverting its subject and observing red
- **Max feedback latency:** ~660 seconds (full suite worst case)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Automated Command | Status | Observed by |
|---------|------|------|-------------|-----------------|-------------------|--------|-------------|
| 24-W0-01 | 01 | 1 | NEXUS-02 | `anonymous.enabled` is a real, wired value (toggling changes the render) | `bash scripts/check-nexus-chart.sh` → `ANONYMOUS-VALUE-PRESENT` | ✅ green | **24-01-SUMMARY** — check 8 rewritten from `ANONYMOUS-NOT-OPENED`; proven non-vacuous by deleting the Job env entry and observing red. A grep on the render cannot decide this (it still returns 7, because the ConfigMap embeds `provision.sh`), so the check reads the rendered Job env through `yq` twice, on a `true`/`false` pair. |
| 24-W0-02 | 01 | 1 | NEXUS-02 | Shipped default matches the locked "OFF, opt-in" decision | same → `ANONYMOUS-DEFAULT` | ✅ green | **24-01-SUMMARY**. Re-confirmed from the merged tree: `git show origin/main:kubernetes/nexus/values.yaml \| yq '.anonymous.enabled'` → `false`. |
| 24-W0-03 | 02 | 3 | NEXUS-02 | Unauthenticated npm tarball → 200 and > 300,000 bytes | `bash scripts/nexus-live-smoke.sh` → `ANONYMOUS-PULL-ALLOWED-{TRANSPORT,HTTP-200,SIZE}` | ✅ green | **24-02-SUMMARY** — measured **318,961 bytes** at HTTP 200, floor 100,000. Three verdicts, not one, so a transport error, a wrong status and a refusal body stay distinguishable. |
| 24-W0-04 | 02 | 3 | NEXUS-02 | Unauthenticated PyPI simple index and Helm `index.yaml` → 200, non-trivial size | same → `ANONYMOUS-PULL-PYPI-*`, `ANONYMOUS-PULL-HELM-*` | ✅ green | **24-02-SUMMARY** — PyPI **76,776 bytes** (floor 20,000), Helm **291,818 bytes** (floor 100,000). Same run measured the EULA/metadata boundary: under `eula.accepted=false` the PyPI page still answers 200 while npm and Helm return 403 at 192 bytes. |
| 24-W0-05 | 05 | 4 | NEXUS-02 | Full Docker handshake (ping 401 + Bearer challenge → token → manifest with `Authorization: Bearer` → 200 → layer blob → 200) | same → `ANONYMOUS-PULL-DOCKER` | ✅ green | **24-05-SUMMARY** — five ordered legs, challenge values parsed from the server's own `WWW-Authenticate`, `linux/amd64` child selected by platform; layer blob **3,626,020 bytes**, floor 1,000,000. Non-vacuity measured: removing `DockerToken` turns leg 4 red at HTTP 401 while legs 1-3 stay green. |
| 24-W0-06 | 05 | 4 | NEXUS-02 | `DockerToken` appears in active realms exactly once after two consecutive provisioning passes | same → `DOCKER-REALM-ACTIVE` | ✅ green | **24-05-SUMMARY** — asserted three ways: present, present exactly once, and `NexusAuthenticatingRealm` not taken down with it. |
| 24-W0-07 | 05 | 4 | NEXUS-02 | `/v2/<repo>/…` → 200 and `/v2/repository/<repo>/…` → 404 | same → `DOCKER-PATH-SHAPE` | ✅ green | **24-05-SUMMARY** — the shape that looks right by analogy is the one that 404s. Closes ADR-020's `What was NOT verified` item 2. |
| 24-W0-08 | 05 | 4 | NEXUS-02 | Anonymous write denied: valid-body POST → 403, admin GET of the name → 404 | same → `ANONYMOUS-WRITE-DENIED` | ✅ green | **24-05-SUMMARY** — carries a third assertion the plan did not ask for (Rule 2): the admin GET must return 200 for a repository that *does* exist, otherwise the 404 proving non-creation could be a wrong URL shape 404ing for everything. |
| 24-W0-09 | 02 | 3 | NEXUS-02 | Both new provisioning calls are idempotent across two consecutive runs | two-pass `run_provision` with the `ANONYMOUS_*` env vars → `PROVISION-PASS-1` / `PROVISION-PASS-2` | ✅ green | **24-01-SUMMARY** (three live passes: open, no-change, close — pass 2 logged "already active — no change, and no request was made") and **24-02-SUMMARY** (the two-pass harness on the anonymous-ENABLED path). The no-change branch is only reachable because both sides are normalised through `jq -c` first — raw `cmp` differs on every run. |
| 24-W0-10 | 07 | 4 | NEXUS-04 | Script writes `.npmrc`; `npm config get registry` returns the Nexus URL | `bash workstation/nexus-setup.sh --url … --verify` | ✅ green | **24-07-SUMMARY** — readback from the client plus a real component fetch with the cache disabled, 8 `--verify` runs against two live Nexus instances. |
| 24-W0-11 | 07 | 4 | NEXUS-04 | Script writes `pip.conf`; pip resolves `global.index-url` to it | `bash workstation/nexus-setup.sh --url … --verify` (**command corrected — see note**) | ✅ green | **24-07-SUMMARY**. **This row's originally stated command is falsified and was replaced.** `pip config get global.index-url` exits 1 with `ERROR: No such key` on pip 26.2.1 under every scope flag, with `PIP_CONFIG_FILE` pointed at a file that plainly carries the key — `get` reads the writable scopes only and cannot see the `:env:` variant `PIP_CONFIG_FILE` creates. The readback uses `pip config list`, which also reports pip's **merged** view, and the fetch additionally asserts pip's own `Looking in indexes:` line. The behaviour is observed; only the command literal was wrong, and the measurement is written into the script beside the call. |
| 24-W0-12 | 07 | 4 | NEXUS-04 | Script writes the repo-scoped Helm repositories file via `helm repo add`; `helm repo list` shows it, global file unchanged | same, plus `bash scripts/check-nexus-setup.sh` → `GLOBAL-CONFIG-UNTOUCHED` | ✅ green | **24-07-SUMMARY** (the `helm search repo -r` anchoring defect measured on helm v4.3.0 and corrected: `-r '^nexus/'` matches nothing because the regexp is not applied to the start of `repo/chart`) and **24-03/24-06** (`GLOBAL-CONFIG-UNTOUCHED`: the operator's Helm config, npm userconfig and `~/.docker/daemon.json` all byte-unchanged across every fixture run). |
| 24-W0-13 | 03 | 1 | NEXUS-04 | Emitted `NEXUS_DOCKER_REGISTRY` contains no `/repository/` segment | `bash scripts/check-nexus-setup.sh` → `DOCKER-PREFIX-SHAPE` | ✅ green | **24-03-SUMMARY** (gate written before its subject, nine single-defect mutations each producing exactly one predicted red) and **24-07-SUMMARY** (the gate green against the real subject: `export NEXUS_DOCKER_REGISTRY="…/docker-proxy"`). |
| 24-W0-14 | 03 | 1 | NEXUS-04 | Existing `.npmrc` content (incl. auth-token line) survives a re-run | `bash scripts/check-nexus-setup.sh` → `NPMRC-MERGE` | ✅ green | **24-03-SUMMARY** (fixture) and **24-06-SUMMARY** (real subject: the seeded auth-token and save-exact lines both survive; the failure mode is structurally impossible — no `>`/`>>` redirect targets `.npmrc` anywhere in the source, asserted by `NPMRC-NO-REDIRECT`). |
| 24-W0-15 | 03 | 1 | NEXUS-04 | Script is not executable and passes shellcheck | `pre-commit run --all-files`; `SETUP-NOT-EXECUTABLE` / `SETUP-SHELLCHECK` | ✅ green | **24-06/24-07-SUMMARY**, and re-confirmed from the merged tree: `git ls-tree -r origin/main -- workstation/nexus-setup.sh` → mode `100644`; `pre-commit run --all-files` exit 0 with shellcheck `Passed`. |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky — **all fifteen rows green; no exceptions**.*

---

## Wave 0 Requirements

- [x] Rewrite `scripts/check-nexus-chart.sh` check 8 → `ANONYMOUS-VALUE-PRESENT`; add `ANONYMOUS-DEFAULT` (plan 24-01, `CHECK_COUNT` 17 → 18)
- [x] New `scripts/check-nexus-setup.sh` owns `DOCKER-PREFIX-SHAPE` and the `.npmrc` merge fixture test (plan 24-03) — homed there rather than in `check-nexus-chart.sh` so the two gate scripts have one owning plan each and `CHECK_COUNT` is never a merge point
- [x] Rewrite `scripts/nexus-live-smoke.sh` `ANONYMOUS-PULL-DENIED` → `ANONYMOUS-PULL-ALLOWED`; add `ANONYMOUS-PULL-PYPI`, `ANONYMOUS-PULL-HELM`, `ANONYMOUS-PULL-DOCKER` (full handshake), `DOCKER-REALM-ACTIVE`, `DOCKER-PATH-SHAPE`, `ANONYMOUS-WRITE-DENIED`
- [x] Update `run_provision()` in the live smoke with the three new `ANONYMOUS_*` env vars (plan 24-01, at `false` so `ANONYMOUS-PULL-DENIED` stays valid at that commit; plan 24-02 flips it to `true` and inverts the check in the same commit) and with `READY_ATTEMPTS` / `READY_INTERVAL` (plan 24-02) — without them the smoke fails under `set -u` the moment `provision.sh` changes
- [x] `workstation/nexus-setup.sh` with a `--verify` mode performing one real fetch per ecosystem
- [x] A fixture-based test for the `.npmrc` merge (pre-existing auth-token line must survive)
- [x] No test framework install needed

---

## Manual-Only Verifications

*None — all phase behaviors have automated (offline or live-gate) verification per RESEARCH.md.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies — 28 tasks across the ten plans; **26 of 26** non-checkpoint tasks carry an `<automated>` block, and the two remaining tasks are the phase's two deliberate human gates (24-04 Task 3, the A3 Docker decision; 24-10 Task 2, the merge approval), which are decision points by design and have no automatable verdict.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify — the strongest gap anywhere in the phase is **one** task, never two.
- [x] Wave 0 covers all MISSING references — every one of the six Wave 0 items above shipped and is ticked; the two gate scripts named `❌ W0` in the original map (`scripts/check-nexus-setup.sh`, and the rewritten checks in the two existing gates) now exist on `origin/main`.
- [x] No watch-mode flags — grepped across all ten PLAN files: zero occurrences.
- [x] Feedback latency < 660s — **measured, not estimated**: the full live suite (docker half + `kind` half, 25 checks) ran end to end in **127 seconds** on 2026-09-20 with images warm, against the ~660 s worst-case estimate. The offline gates are seconds. Caveat recorded honestly: `sonatype/nexus3:3.96.0-ubi` and `kindest/node` were already cached locally, and the script's own header excludes image pulls from its estimate, so a cold workstation will be slower.
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** **SIGNED OFF 2026-09-20**, against `OttawaCloudConsulting/security-platform` `origin/main` at `aed14b9` (the merge commit of PR #15), not against the local working tree.

All fifteen `24-W0-xx` rows are green with the SUMMARY that observed each one named in the row. **One row carries a correction rather than a plain pass**: `24-W0-11`'s originally stated command, `pip config get global.index-url`, was *measured to be unusable* on pip 26.2.1 and was replaced with `pip config list` plus an assertion on pip's own `Looking in indexes:` line. The behaviour the row exists to verify — the script writes `pip.conf` and pip resolves its index through Nexus — is observed; only the command literal was wrong. That is recorded here rather than silently rewritten, because a validation contract that quietly edits its own assertions to match what passed is worth nothing.

### Post-merge confirmation

Read from `origin/main` only (`git fetch` then `git ls-tree` / `git show`), never from the local working tree, per the Phase 23 T-23-12 evidence rule:

- Merge commit `aed14b916e9aa8ec1d0d47699b457040b99f7eac`, parents `ea2770f` (the branch point) + `c3ba864` (the gated branch tip), merged `2026-09-20T20:46:24Z`.
- **The merged tree hash equals the gated tree hash** — `origin/main^{tree}` and `c3ba864^{tree}` are both `a4a79626fbd3782ed1d2e9f55c5ed5a0d3c89811`, so what was verified is exactly what shipped.
- All nine shipped paths present on `origin/main`; `workstation/nexus-setup.sh` and `scripts/check-nexus-setup.sh` both mode `100644`.
- Both standing offline gates re-run **against the merged tree**: `PASS - 18 checks, 0 failures` and `ALL PASS - 12 check(s) executed and passed; 0 sub-check(s) skipped (not passed).`
- `git ls-remote --heads origin feature/phase-24-nexus-anonymous-and-workstation` prints nothing — the feature branch is deleted on the remote. Determined by `ls-remote`, not by a local branch listing.
