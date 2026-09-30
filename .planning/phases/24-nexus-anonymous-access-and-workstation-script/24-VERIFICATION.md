---
phase: 24-nexus-anonymous-access-and-workstation-script
verified: 2026-09-20T21:04:35Z
status: human_needed
score: 7/9 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Independently re-run `bash scripts/nexus-live-smoke.sh` in security-platform against a fresh Nexus container/kind cluster and confirm ALL PASS with ANONYMOUS-PULL-ALLOWED-*, ANONYMOUS-PULL-PYPI-*, ANONYMOUS-PULL-HELM-*, ANONYMOUS-PULL-DOCKER, DOCKER-REALM-ACTIVE, DOCKER-PATH-SHAPE, ANONYMOUS-WRITE-DENIED all green"
    expected: "25 live checks, 0 skipped, ALL PASS — matching 24-02-SUMMARY.md and 24-05-SUMMARY.md's recorded executor runs"
    why_human: "This probe requires a live Docker daemon and ~3-11 minutes of Nexus/kind bring-up, which exceeds the verifier's 10s spot-check / 30s probe budget and the 'do not start services' constraint. The verifier confirmed the assertion logic is real (grep-traced every fail/pass branch and the five-leg Docker handshake in scripts/nexus-live-smoke.sh, confirmed the file is syntax-valid via `bash -n`) and confirmed ANONYMOUS_ENABLED=true is wired into run_provision(), and cites the executor's own reversion-tested, byte-measured SUMMARY output as strong indirect evidence, but did not execute the live probe itself."
---

# Phase 24: Nexus Anonymous Access and Workstation Script Verification Report

**Phase Goal:** Nexus proxy repos allow anonymous pull (no auth required for read/proxy access), and a workstation install script configures a target repo's package-manager files (`.npmrc`, `pip.conf`, Docker/Helm registry config) to route through a given Nexus instance.
**Requirements:** NEXUS-02, NEXUS-04
**Verified:** 2026-09-20T21:04:35Z (against `OttawaCloudConsulting/security-platform` `origin/main` @ `aed14b916e9aa8ec1d0d47699b457040b99f7eac`, merge of PR #15)
**Status:** human_needed
**Re-verification:** No — initial goal-backward verification. Note: a file already existed at this path (`24-VERIFICATION.md`, committed at `451ba0f`) but it was `gsd-plan-checker`'s **pre-execution plan-quality** report (no `gaps:` frontmatter, dated before merge). Per Step 0 this does not count as a prior goal-backward verification; it is superseded here and preserved in git history.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A consumer can decide anonymous read via one chart value, default closed | VERIFIED | `kubernetes/nexus/values.yaml:98-141` — `anonymous.enabled: false` top-level block; `check-nexus-chart.sh` → `ANONYMOUS-DEFAULT` PASS (re-run live by verifier, exit 0, 18/18) |
| 2 | The value reaches the provisioning Job and is not inert | VERIFIED | `kubernetes/nexus/templates/job-provision.yaml:153-158` sets `ANONYMOUS_ENABLED`/`ANONYMOUS_USER_ID`/`ANONYMOUS_REALM_NAME` env from `.Values.anonymous.*`; `ANONYMOUS-VALUE-PRESENT` gate reads the rendered value both ways (verifier re-ran `check-nexus-chart.sh`, PASS) |
| 3 | provision.sh sets server-side anonymous state unconditionally and idempotently | VERIFIED | `kubernetes/nexus/files/provision.sh:222-262` — unconditional `PUT /service/rest/v1/security/anonymous`, explicit rationale comment for why it is not guarded, idempotent-echo branches for both true/false |
| 4 | An unauthenticated client can pull real npm/PyPI/Helm artifacts through the proxy | UNCERTAIN (code verified, live-run not independently reproduced by verifier) | `scripts/nexus-live-smoke.sh:420-547` — real HTTP-200 + byte-floor assertions per ecosystem, verifier grep-traced all fail/pass branches, confirmed `bash -n` syntax-valid; 24-02-SUMMARY.md records an actual executor run at HTTP 200, 318,961 / 76,776 / 291,818 bytes, with reversion tests proving the checks are non-vacuous. See Human Verification. |
| 5 | A real Docker client can pull anonymously (full bearer handshake), and write stays denied | UNCERTAIN (code verified, live-run not independently reproduced by verifier) | `scripts/nexus-live-smoke.sh:722-966` — 5-leg handshake (ping→401+challenge→token→bearer manifest 200→layer blob), `DOCKER-REALM-ACTIVE`, `DOCKER-PATH-SHAPE` (200 vs 404), `ANONYMOUS-WRITE-DENIED` (403 + admin-GET 404 non-creation proof). 24-05-SUMMARY.md records executor run: 3,626,020-byte layer blob streamed. See Human Verification. |
| 6 | One command routes a target repo's npm/pip/Helm clients at a Nexus instance | VERIFIED | `workstation/nexus-setup.sh:477-673` `configure_npm`/`configure_pip`/`configure_helm`, real `npm config set --location=project`, hand-written `pip.conf` (measured `pip config set` fails under `PIP_CONFIG_FILE`), `helm repo add`; verifier re-ran `check-nexus-setup.sh` live → `NPMRC-MERGE`, `DOCKER-PREFIX-SHAPE`, `PIP-TRUSTED-HOST-CONDITIONAL` all PASS (12/12, exit 0); verifier also ran `bash workstation/nexus-setup.sh --help`, exit 0, output names `--verify` and `--docker-daemon` |
| 7 | Existing `.npmrc`/pip/Helm config and files outside the target repo survive untouched | VERIFIED | `check-nexus-setup.sh` → `GLOBAL-CONFIG-UNTOUCHED` PASS (verifier re-run), `NPMRC-NO-REDIRECT` PASS (structurally impossible to clobber — no `>`/`>>` redirect targets `.npmrc` anywhere in source) |
| 8 | Docker routing is honestly reported as manual/opt-in, never as a configured pass | VERIFIED | `workstation/README.md:263-265` — `MANUAL` row always; `nexus-setup.sh` `--docker-daemon` off by default, `configure_docker_daemon` gated at line 855/1619; `DOCKER-DAEMON-WARNING` gate PASS (verifier re-run) |
| 9 | Decision record exists, supersedes ADR-020 in prose without editing it, states what was NOT verified, and closes out Phase 23's deferred items 2 and 3 | VERIFIED | `docs/adr/adr021-nexus-anonymous-read-and-workstation-routing.md` (321 lines, accepted, dated 2026-09-20, `## What was NOT verified` section present, ADR-020 untouched per append-only rule); `docs/adr/README.md` contains exactly one `ADR-021` reference (index row present); ADR-021 lines 168 and 182 explicitly close Phase 23 deferred items 2 and 3 |

**Score:** 7/9 truths independently VERIFIED by the verifier at the code level; 2/9 (the live-network proof of anonymous pull for npm/PyPI/Helm/Docker) rest on strong, reversion-tested executor evidence in SUMMARY.md that the verifier did not itself reproduce, given the live-infra/time-budget constraint on this verification pass. `score` in frontmatter reflects the independently-verified count (7/9), not the code+executor-evidence combined count.

### Important Note: Default-Off Deviation from Literal Requirement Wording

REQUIREMENTS.md states NEXUS-02 as "Proxy repos allow anonymous pull (no auth required for read/proxy access)" with no explicit default stated. The shipped chart defaults `anonymous.enabled: false` — a fresh install does **not** allow anonymous pull out of the box; the consumer must opt in. This is **not an unexplained gap**: `24-CONTEXT.md` line 19 explicitly locks "OFF (opt-in) by default... safer default than open-by-default" as a phase-scoped decision (and is itself truth #1 of plan 24-01's own must_haves, so plan and shipped behavior agree), and `kubernetes/nexus/README.md:46` documents the requirement as "Complete (Phase 24) — **opt-in**". The capability is fully implemented, tested, and documented; only the shipped default is conservative. This reads as an intentional, well-documented product decision rather than a shortfall, and REQUIREMENTS.md/ROADMAP.md both mark NEXUS-02 complete with this framing. No override entry is added because the deviation is already disclosed in-repo at the point a reader would look (chart README, ADR-021); flagging here for visibility only.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `kubernetes/nexus/values.yaml` | `anonymous:` block, default false | VERIFIED | 77 lines changed per merge diff, wired |
| `kubernetes/nexus/files/provision.sh` | Anonymous PUT + guarded DockerToken realm append, ≥290 lines | VERIFIED | 385 lines total (148 added), well over the 290-line floor; unconditional PUT confirmed at line 246, guarded realm append confirmed via `DOCKER-REALM-ACTIVE` assertions |
| `kubernetes/nexus/templates/job-provision.yaml` | Env wiring for the three anonymous values | VERIFIED | Lines 153-158 |
| `scripts/check-nexus-chart.sh` | 18 offline checks incl. `ANONYMOUS-VALUE-PRESENT`, `ANONYMOUS-DEFAULT` | VERIFIED | Re-run live by verifier: `PASS - 18 checks, 0 failures`, exit 0 |
| `scripts/check-nexus-setup.sh` | New file, ≥200 lines, offline gate for workstation script | VERIFIED | 747 lines added (new file); re-run live by verifier: `ALL PASS - 12 checks, 0 skipped`, exit 0 |
| `scripts/nexus-live-smoke.sh` | Anonymous pull + Docker handshake assertions | VERIFIED (code); not independently re-executed live | 620 lines added; all named markers present and logically sound on inspection; syntax-valid (`bash -n`) |
| `workstation/nexus-setup.sh` | New file, ≥330 lines (07's floor), npm/pip/Helm/docker writers + `--verify` | VERIFIED | 1637 lines (new file); not executable (mode 100644, correct per Script Safety rule); shellcheck clean; `--help` runs, exit 0 |
| `docs/adr/adr021-...md` | ≥90 lines, accepted, "What was NOT verified" section | VERIFIED | 321 lines, well over the 90-line floor, present in `security_solution` repo (documentation side, not security-platform) |
| `kubernetes/nexus/README.md`, `workstation/README.md` | Anonymous section + 4 URL shapes; nexus-setup.sh usage + Docker honesty | VERIFIED | Both confirmed present and accurate on inspection (README excerpts above) |
| `.planning/phases/24-.../24-evidence/a3-docker-daemon-routing.md` | Recorded VERDICT driving the 24-07 decision | VERIFIED | Line 256: `VERDICT: A3-FALSIFIED-CANDIDATE-1`, referenced again at line 318 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `values.yaml` (`anonymous.enabled`) | `job-provision.yaml` | `.Values.anonymous.enabled` template ref | WIRED | Confirmed by grep + live gate |
| `job-provision.yaml` (env) | `provision.sh` | `ANONYMOUS_ENABLED` env var read | WIRED | `provision.sh` reads `${ANONYMOUS_ENABLED}` and drives the PUT body/idempotent-echo branch |
| `provision.sh` | Nexus REST API | `PUT /service/rest/v1/security/anonymous`, realm append | WIRED | Confirmed present, unconditional, with fatal-on-non-200 guard |
| `nexus-live-smoke.sh` `run_provision()` | provisioning env | `ANONYMOUS_ENABLED=true` | WIRED | Confirmed at line 181 |
| `workstation/nexus-setup.sh` | target repo `.npmrc` | `npm config set registry --location=project` | WIRED | Confirmed, no redirect mechanism exists (structurally proven by `NPMRC-NO-REDIRECT` gate) |
| `workstation/nexus-setup.sh` | target repo `pip.conf` | hand-written file (not `pip config set`, measured broken) | WIRED | Confirmed, `configure_pip` at line 558+ |
| `workstation/nexus-setup.sh` | Helm repositories.yaml (repo-scoped) | `helm repo add` | WIRED | Confirmed, `HELM-NOT-HANDWRITTEN` gate PASS |
| `workstation/nexus-setup.sh --docker-daemon` | `~/.docker/daemon.json` | `configure_docker_daemon`, opt-in flag | WIRED | Confirmed gated at line 1619, ADR-009 warning present (`DOCKER-DAEMON-WARNING` gate PASS) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Workstation script runs and documents its own interface | `bash workstation/nexus-setup.sh --help` | Exit 0, usage text names `--url`, `--verify`, `--docker-daemon` | PASS |
| Live-smoke script is syntactically valid (partial independent evidence for the probe not run live) | `bash -n scripts/nexus-live-smoke.sh` | Exit 0, no syntax errors | PASS |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| `scripts/check-nexus-chart.sh` | `bash scripts/check-nexus-chart.sh` | `PASS - 18 checks, 0 failures`, exit 0 | PASS |
| `scripts/check-nexus-setup.sh` | `bash scripts/check-nexus-setup.sh` | `ALL PASS - 12 check(s) executed and passed; 0 sub-check(s) skipped`, exit 0 | PASS |
| `scripts/nexus-live-smoke.sh` | `timeout 30s bash scripts/nexus-live-smoke.sh` | NOT RUN — file exists and is syntax-valid, but requires a live Docker daemon and ~3-11 min of Nexus/kind bring-up | SKIP (not MISSING_PROBE — the probe file exists and was read; execution was excluded under the "do not start services" / time-budget constraint, and routed to Human Verification) |

Both offline gates were re-run live by the verifier in this session against the actual checked-out `origin/main` tree (not trusted from SUMMARY.md), and both are non-vacuous by the gate scripts' own `NOTHING RAN` convention plus their documented reversion tests in the executor SUMMARYs.

### Anti-Patterns Found

None. Scanned all phase-touched files (`values.yaml`, `provision.sh`, `job-provision.yaml`, `check-nexus-chart.sh`, `check-nexus-setup.sh`, `nexus-live-smoke.sh`, `nexus-setup.sh`) for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER|not yet implemented|coming soon`. Two matches, both false positives (`mktemp ... XXXXXX` — a mktemp template placeholder, not a debt marker). No stub returns, no empty handlers, no hardcoded-empty props found in the substantive code read.

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|---|---|---|---|
| NEXUS-02 | Proxy repos allow anonymous pull, no auth required for read/proxy access | SATISFIED (opt-in, documented deviation from a literal "no auth required" reading — see note above) | Server-side implementation complete and live-gate-proven per executor SUMMARY; verifier confirmed wiring and offline gates live |
| NEXUS-04 | Workstation install script configures npm/pip/Docker/Helm registry config | SATISFIED | `workstation/nexus-setup.sh` fully implements npm/pip/Helm per-repo routing + Docker global opt-in with `--verify` proof pass; verifier confirmed offline gate live, ran `--help`, and read the writer functions directly |

No orphaned requirements: REQUIREMENTS.md maps only NEXUS-02 and NEXUS-04 to Phase 24, and both appear in plan frontmatter (checked across all 10 plans).

### Deferred Items

None applicable — NEXUS-05 (live cluster/ArgoCD validation, Phase 25) is a distinct scope (cluster deploy) from this phase's local Docker-daemon smoke-test proof, so it is not a defer target for the one open human-verification item above.

### Human Verification Required

#### 1. Independent live-infra re-run of `nexus-live-smoke.sh`

**Test:** From `repos/security-platform`, run `bash scripts/nexus-live-smoke.sh` (docker half at minimum; kind half if validating the in-cluster env-var wiring too) against a fresh Nexus container.
**Expected:** `ALL PASS`, 25 live checks, 0 skipped — matching the counts recorded in 24-02-SUMMARY.md (21 checks after that plan) and 24-05-SUMMARY.md (25 checks after that plan), with `ANONYMOUS-PULL-ALLOWED-*`, `ANONYMOUS-PULL-PYPI-*`, `ANONYMOUS-PULL-HELM-*`, `ANONYMOUS-PULL-DOCKER`, `DOCKER-REALM-ACTIVE`, `DOCKER-PATH-SHAPE`, and `ANONYMOUS-WRITE-DENIED` all green.
**Why human:** Requires a live Docker daemon and several minutes of Nexus/kind bring-up — outside the verifier's spot-check time budget and the constraint against starting services. The verifier instead traced every assertion branch in the 620 added lines of `nexus-live-smoke.sh`, confirmed the file is syntax-valid, and confirmed the logic is sound (real HTTP status codes, byte floors that distinguish a real artifact from an EULA-refusal body or a 401 challenge, a genuine 5-leg Docker bearer-token handshake) — and cites the executor's own reversion-tested run as strong indirect evidence — but "the executor said it passed" is not independent proof, per this verification's mandate.

### Gaps Summary

No code-level gaps found. Every artifact the plans committed to exists, is substantive (not a stub), and is wired end-to-end from `values.yaml` through to the Nexus REST API on the server side, and from the workstation script through to real client config files on the workstation side. Both offline gates were re-run live in this session and are green with no vacuous passes; all artifact line-count floors from plan frontmatter were checked and exceeded. The one open item is not a defect but a verification-method limitation: the live network proof of anonymous pull (npm/PyPI/Helm/Docker) exists only as executor-recorded evidence, not as an independently-reproduced verifier observation, because reproducing it requires live Docker/Nexus infrastructure outside this verification pass's budget. The default-off posture for `anonymous.enabled` is a disclosed, intentional deviation from a literal "no auth required" reading of NEXUS-02's requirement text, locked in 24-CONTEXT.md (itself part of plan 24-01's must_haves) and documented in the shipped README — not an unexplained gap.

---

_Verified: 2026-09-20T21:04:35Z_
_Verifier: Claude (gsd-verifier)_
