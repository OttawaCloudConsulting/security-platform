---
phase: 24-nexus-anonymous-access-and-workstation-script
plan: 06
subsystem: infra
tags: [bash, workstation, nexus, npm, pip, helm, docker, shellcheck, gitignore, adr-009]

# Dependency graph
requires:
  - phase: 24-nexus-anonymous-access-and-workstation-script
    provides: "scripts/check-nexus-setup.sh — the twelve-check offline gate written before its subject (plan 24-03), including the binding ordering contract (.npmrc and pip.conf before `helm repo add`) and the NEXUS_SETUP_GATE_SUBJECT test hook"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    provides: "The operator's recorded `daemon-opt-in` decision and the A3 verdict (plan 24-04) — consumed here as the reason this plan writes no daemon configuration at all and keeps DOCKER-DAEMON-WARNING honestly SKIPPED"
  - phase: 12-workstation-setup-script
    provides: "workstation/setup.sh — the analog whose header, four logging functions, write_config, REPO_ROOT derivation and FAIL_COUNT exit convention were copied (its 755 file mode deliberately was not)"
provides:
  - "workstation/nexus-setup.sh — one command that routes a repository's npm, pip and Helm clients at a given Nexus and emits the sourceable env file that makes two of those three take effect"
  - "A validated --url interface (T-24-27): scheme allowlist, conservative character class, single trailing-slash strip, numeric-port rule — nothing is written before validation returns"
  - "A measured-and-observed gate shape for plan 24-07 to work against: exactly one failure, VERIFY-FAILS-LOUDLY, plus one honest SKIPPED"
  - "A --verify arm that refuses in one line without printing usage, so the gate's red-to-green transition for plan 24-07 is real rather than vacuous"
affects: [24-07, 24-08, 24-09, 24-10, phase-25-nexus-live-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Caught branch, not swallowed `|| true`: a network-reaching call inside a configuration writer captures its exit code, warns with the tool's own output, counts the failure and continues, so an unreachable service does not cost the developer the files that do not depend on it"
    - "The pessimistic default status string: every per-ecosystem row initialises to 'not configured (writer never ran)', so a row that was never reached can never read as a pass"
    - "Emit a TLS-bypass directive only where the client's own trust rules require it, and put the ADR-009 removal sentence in the generated file rather than only in the generator"
    - "Refuse a recognised-but-unimplemented flag in one line without printing usage, so a gate asserting that the flag names a failing ecosystem stays red until the flag is real"

key-files:
  created:
    - repos/security-platform/workstation/nexus-setup.sh
  modified: []

key-decisions:
  - "`--verify` gets its own case arm that errs in one line and exits 1 WITHOUT printing usage. Printing usage would have turned VERIFY-FAILS-LOUDLY green today — measured — because the usage text names npm and pip, which is the only thing that check greps for besides a non-zero exit. That would have handed plan 24-07 a check with no red-to-green transition to observe."
  - "write_config() moved from task 1 to the task 2 commit. The plan asked task 1 for both write_config and a shellcheck-clean file; at that commit the function has no caller and shellcheck SC2329 makes those two requirements mutually exclusive. The function is present, copied from setup.sh with --force handling, at the commit where it is first used."
  - "`helm repo add` is invoked with --force-update, so a re-run with a DIFFERENT --url replaces the `nexus` entry instead of erroring. Measured on helm v4.3.0: a same-config re-add is already a no-op exit 0, so --force-update only changes the different-URL case. Stated in --help."
  - "--url keeps any path component for the npm/pip/Helm URLs but drops it from the Docker prefix, with a warn naming the asymmetry: a Docker client inserts /v2/ immediately after the host, so there is no room for it."
  - "Bracketed IPv6 literals are rejected by the --url validator. The conservative character class that keeps shell metacharacters out of a string destined for files clients obey also excludes '[' and ']'. Recorded as a known input limitation in the script header rather than papered over with a looser class."

patterns-established:
  - "Pattern: when a gate cannot exit 0 at an intermediate commit, predict the exact failure SET before running it and quote the observed set — the 17-04 precedent, honoured here and observed to match exactly."
  - "Pattern: hold a filename in a variable when a source-level gate forbids that filename appearing after a redirect, so no future refactor can place the two on one line."
  - "Pattern: repeat a measured, counter-intuitive fact in the GENERATED file and not only in the generator, because the generated file is what the developer reads."

requirements-completed: []  # NEXUS-04 is withheld on purpose — plan 24-10 marks it after merge.

# Metrics
duration: ~50min
completed: 2026-09-20
---

# Phase 24 Plan 06: The Workstation Nexus Routing Script Summary

**`workstation/nexus-setup.sh` routes one repository's npm, pip and Helm clients at a given Nexus through the three mechanisms that were actually measured to work, preserves an existing `.npmrc` credential byte-identically, gitignores what it generates by default, and refuses to claim a success it has not proven — leaving `scripts/check-nexus-setup.sh` at exactly the one predicted failure, `VERIFY-FAILS-LOUDLY`.**

## Performance

- **Duration:** ~50 min
- **Started:** 2026-09-19T23:25Z
- **Completed:** 2026-09-20T00:15Z
- **Tasks:** 3 (all `auto`, no checkpoints)
- **Files created:** 1 (842 lines, mode 644)

## Task Commits

All three are in `repos/security-platform`, on `feature/phase-24-nexus-anonymous-and-workstation`. Each commit's `git diff-tree --no-commit-id --name-only -r` lists exactly `workstation/nexus-setup.sh` and nothing else.

| Task | Commit | Subject |
|------|--------|---------|
| 1 — scaffold, argument parsing, `--url` validation | `dc01b0f` | `feat(24-06): scaffold workstation/nexus-setup.sh with validated --url interface` |
| 2 — the npm and pip writers | `3c41ab8` | `feat(24-06): add the npm and pip writers to nexus-setup.sh` |
| 3 — Helm, `.nexus-env`, `.gitignore`, report | `4bdb5e9` | `feat(24-06): add workstation/nexus-setup.sh — per-repo npm, pip and Helm routing` |

## Accomplishments

- One command points a repository's npm, pip and Helm at a Nexus, and says in writing which of the three actually route without further action (npm) and which are inert until `.nexus-env` is sourced (pip, Helm).
- The npm credential-loss failure mode is structurally impossible in this script rather than merely avoided: there is no redirect onto `.npmrc` anywhere in the source, the filename is held in a variable so no refactor can place it after one, and the merge is done by `npm config set --location=project`, measured non-destructive.
- Every hazard in the research is warned about at the point it applies rather than absorbed: the npm local-prefix trap, an already-tracked `.npmrc`, the `PIP_CONFIG_FILE` user-scope replacement (with the developer's own orphaned keys named when a user `pip.conf` carries any), and an unreachable chart repository.
- The TLS-bypass directive is emitted only where pip's own `SECURE_ORIGINS` leaves a real gap, with the ADR-009 warning beside it in the generated file.
- The run ends on a per-ecosystem report and an explicit NOT PROVEN paragraph. There is no "Setup complete" line anywhere in the script.
- The operator's global Helm repository list, npm userconfig and `~/.docker/daemon.json` are byte-identical before and after every run made during this plan — measured directly, not inferred from the gate.

## Measured Evidence

### 1. The gate, with its single predicted failure

Predicted in the plan before the run: exactly one failure, `VERIFY-FAILS-LOUDLY`, plus a `SKIPPED` for `DOCKER-DAEMON-WARNING`. Observed, verbatim:

```
check-nexus-setup: asserting offline invariants against workstation/nexus-setup.sh
==> SETUP-NOT-EXECUTABLE: PASS - workstation/nexus-setup.sh is not executable, as the project Script Safety rule requires
==> SETUP-SHELLCHECK: PASS - shellcheck reports no findings on workstation/nexus-setup.sh
==> NPMRC-NO-REDIRECT: PASS - no '>' or '>>' redirect targets .npmrc anywhere in the non-comment source
==> HELM-NOT-HANDWRITTEN: PASS - the subject shells out to 'helm repo add' and never writes repositories.yaml itself
==> VERIFY-NO-SILENT-TRUE: PASS - no '|| true' appears anywhere in the non-comment source
==> DOCKER-DAEMON-WARNING: SKIPPED - workstation/nexus-setup.sh contains no write to daemon.json — plan 24-04's A3 verdict may be that the Docker daemon must not be touched at all, so absent code here is by design and not a defect. This check binds only once such a write exists.
==> NPMRC-MERGE: PASS - the seeded auth-token and save-exact lines both survived and npm resolves the registry to https://nexus.example.com/repository/npm-proxy/
==> DOCKER-PREFIX-SHAPE: PASS - the emitted prefix is 'export NEXUS_DOCKER_REGISTRY="127.0.0.1:62746/docker-proxy"' — host present, docker-proxy named, no /repository/ segment
==> PIP-TRUSTED-HOST-CONDITIONAL: PASS - trusted-host appears only for plain http to a non-loopback host, and carries the ADR-009 removal sentence when it does
==> NEXUS-ENV-EXPORTS: PASS - the env file exports exactly the four contracted variables and states both the sourcing requirement and the PIP_CONFIG_FILE user-scope consequence
==> GLOBAL-CONFIG-UNTOUCHED: PASS - the operator's Helm repository config, npm userconfig and ~/.docker/daemon.json are all byte-unchanged across every fixture run
==> VERIFY-FAILS-LOUDLY: FAIL - --verify exited 1, which is correct, but its output names no ecosystem — a developer cannot tell which client is still going to the public internet. Output: ERROR: --verify is not implemented in this version of the script. Nothing was verified and nothing was written.

=== Summary ===
SKIPPED - 1 sub-check(s) did not run. A SKIP IS NOT A PASS:
  - DOCKER-DAEMON-WARNING: workstation/nexus-setup.sh contains no write to daemon.json — plan 24-04's A3 verdict may be that the Docker daemon must not be touched at all, so absent code here is by design and not a defect. This check binds only once such a write exists.

FAILED - 1 check(s) did not produce the expected result:
  - VERIFY-FAILS-LOUDLY: --verify exited 1, which is correct, but its output names no ecosystem — a developer cannot tell which client is still going to the public internet. Output: ERROR: --verify is not implemented in this version of the script. Nothing was verified and nothing was written.
```

`gate-exit=1`. The prediction and the observation match exactly — one failure, that failure, and one skip.

### 2. The `.npmrc` merge, before and after

Throwaway git repository with a `package.json` (so npm's local prefix resolves there, not to some ancestor). Seeded `.npmrc`:

```
//registry.example.com/:_authToken=SEEDTOKEN123
save-exact=true
```

After `bash workstation/nexus-setup.sh --url https://nexus.example.com`:

```
//registry.example.com/:_authToken=SEEDTOKEN123
save-exact=true
registry=https://nexus.example.com/repository/npm-proxy/
```

Both seeded lines survived byte-identically; the registry line was appended. The gate's own `NPMRC-MERGE` corroborates this from npm's side, asserting what `npm config list --json` resolves rather than what the file contains.

### 3. The three `pip.conf` variants

**`--url https://nexus.example.com`** — no bypass directive, and the file says why it is absent rather than leaving the absence unexplained:

```ini
# pip.conf — generated by workstation/nexus-setup.sh
#
# This file is inert on its own. pip has no project scope and no cwd-relative
# configuration path, so nothing here applies until PIP_CONFIG_FILE points at
# it: run 'source .nexus-env' in this shell first.
#
# No TLS-bypass directive is emitted here, and that is deliberate rather than an
# omission: pip's own SECURE_ORIGINS already trusts https anywhere and any
# scheme to localhost or 127.0.0.0/8, so adding one would disable a
# certificate check that is currently working.
[global]
index-url = https://nexus.example.com/repository/pypi-proxy/simple
```

**`--url http://nexus.example.com`** — plain HTTP to a non-loopback host, the one case where pip genuinely refuses the index without it:

```ini
[global]
index-url = http://nexus.example.com/repository/pypi-proxy/simple

# SECURITY WARNING (ADR-009). The directive below does not merely permit plain
# HTTP. It disables TLS certificate verification for nexus.example.com
# entirely, so anything positioned between this machine and that host can
# substitute packages and pip will raise no certificate error. It is present
# only because --url gave a plain http:// URL for a non-loopback host.
# It MUST be removed once TLS is configured on this Nexus instance.
trusted-host = nexus.example.com
```

**`--url http://127.0.0.1:8081`** — loopback, already inside pip's `SECURE_ORIGINS`, so no directive:

```ini
[global]
index-url = http://127.0.0.1:8081/repository/pypi-proxy/simple
```

Occurrence count of the string `trusted-host` in each generated file: https `0`, http-non-loopback `1`, http-loopback `0`.

### 4. `.nexus-env`, verbatim

From a throwaway repository routed at the loopback Helm stub on port 62626:

```bash
# .nexus-env — generated by workstation/nexus-setup.sh
#
# source this file; do not execute it:
#
#     source .nexus-env
#
# What actually depends on it:
#   npm     Nothing. npm reads its project-scoped config natively and is
#           already routed with no environment set at all.
#   pip     Everything. pip has no project scope, so pip.conf in this
#           repository is inert until PIP_CONFIG_FILE below points at it.
#   Helm    Everything. Helm has no project scope either, so the repository
#           entry created for this repository is invisible to helm until
#           HELM_REPOSITORY_CONFIG below points at it.
#   Docker  Nothing automatic. Docker has no per-repository configuration of
#           any kind. NEXUS_DOCKER_REGISTRY below is a prefix string, and
#           routing an image is a MANUAL edit of an image reference.
#
# WARNING. PIP_CONFIG_FILE REPLACES your user-level pip configuration rather
# than adding to it. Measured: with it set, 'pip config list -v' no longer
# lists EITHER user-scope variant, so your own pip settings — a corporate CA
# bundle, an extra-index-url — silently stop applying in this shell.
#
# Source this in a shell session. Never add it to a shell rc file (.bashrc,
# .zshrc and friends): that would make one repository's Nexus the default for
# every project on this machine, which is the global workstation default this
# script is deliberately scoped to avoid.

export PIP_CONFIG_FILE="<repo>/pip.conf"
export HELM_REPOSITORY_CONFIG="<repo>/.helm/repositories.yaml"
export HELM_REPOSITORY_CACHE="<repo>/.helm/cache"

# MEASURED, and the one asymmetry in this file: the Docker prefix carries NO
# '/repository/' segment, while the npm, pip and Helm URLs all do. A Docker
# client inserts '/v2/' immediately after the host, so the repository name has
# to be the first path segment; the '/repository/'-prefixed reference returns
# HTTP 404. Use it like this:
#
#     docker pull 127.0.0.1:62626/docker-proxy/library/alpine:3.21
export NEXUS_DOCKER_REGISTRY="127.0.0.1:62626/docker-proxy"
```

(`<repo>` stands in for the absolute throwaway path, which is the only thing elided.) The emitted `NEXUS_DOCKER_REGISTRY` line contains `docker-proxy` and does not contain `/repository/`.

### 5. The unreachable-Helm run — non-zero exit, and the env file survives

```console
$ bash workstation/nexus-setup.sh --url http://nexus.invalid-host-for-test.example
WARNING: 'helm repo add nexus http://nexus.invalid-host-for-test.example/repository/helm-proxy/' exited 1;
Helm is NOT routed. Helm fetches index.yaml during 'repo add', so an unreachable or non-Helm URL fails
here. Helm's own output: Error: looks like "http://nexus.invalid-host-for-test.example/repository/helm-proxy/"
is not a valid chart repository or cannot be reached: Get
"http://nexus.invalid-host-for-test.example/repository/helm-proxy/index.yaml": dial tcp: lookup
nexus.invalid-host-for-test.example: no such host
…
helm      not configured (repository unreachable — 'helm repo add' exited 1)
…
rc=1
```

Artefacts left behind by that failed run: `.git .gitignore .helm .nexus-env .npmrc package.json pip.conf` — the env file and the gitignore entries were written despite the Helm failure, which is the whole reason that call is a caught branch rather than a fatal one. The run still exits 1.

### 6. Idempotency, twice over

Second run against the same reachable stub, same URL: exit 0, `helm repo add` clean, `.gitignore` byte-identical to the first run (`diff` reports no difference), `.npmrc` carries one `registry=` line, and the report reads `Files generated this run: 0 (existing files are left alone unless --force)`. With `--force`, `pip.conf` and `.nexus-env` are rewritten with the new URL.

### 7. Global configuration, before and after

Measured directly with `shasum -a 256`, by this plan rather than by the gate:

| Target | Before | After |
|--------|--------|-------|
| `~/Library/Preferences/helm/repositories.yaml` | `f573be9315bf7642ea29005bdfe5b8f65e784403fb8ebbbbef3d7f9ff623c5cb` | `f573be9315bf7642ea29005bdfe5b8f65e784403fb8ebbbbef3d7f9ff623c5cb` |
| `~/.npmrc` (npm userconfig) | ABSENT | ABSENT |
| `~/.docker/daemon.json` | `27369c832f1be7d067b379f3236a203993e7bec45135e58829a9273c3209f53c` | `27369c832f1be7d067b379f3236a203993e7bec45135e58829a9273c3209f53c` |

`helm repo list` against the operator's real global config still lists the same 33 entries (`rook-release longhorn concourse metrics-server … sonatype stevehipwell`) and no `nexus` entry was added to it.

### 8. `--url` rejection table

Every row exits 1, names the rule that failed, and writes nothing:

| `--url` value | Rule that failed |
|---------------|------------------|
| `ftp://x` | scheme allowlist |
| `http://a;rm -rf /` | character rule |
| `http://a$(id)` | character rule |
| `http://a b` | character rule |
| `http://` | host rule (nothing after the scheme) |
| `https://h//` | trailing-slash rule (more than one) |
| `http://h:notaport` | port rule (not a number) |
| `http://[::1]:8081` | character rule (bracketed IPv6 not supported) |

`--url https://nexus.example.com/` and `--url https://nexus.example.com` produce identical derived values (`https://nexus.example.com`, host `nexus.example.com`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] `--verify` given its own case arm, not the generic unknown-argument branch**

- **Found during:** Task 1, while reading `scripts/check-nexus-setup.sh` check 12 against the plan's predicted failure shape.
- **Issue:** The plan says to "reject anything else with `err` plus `usage` and exit 1", and separately predicts that `VERIFY-FAILS-LOUDLY` will be the one failing check. Those two are incompatible. Check 12 fails only if `--verify` exits 0, **or** if the run's output names no ecosystem; the `--help` text names npm and pip in several places, so an `err`+`usage` rejection would have satisfied the check and turned it green — for a run that verified nothing. That is a vacuous pass, and it would have left plan 24-07 with no red-to-green transition to observe on the check it exists to satisfy.
- **Fix:** `--verify` gets its own case arm that prints one line (`--verify is not implemented in this version of the script. Nothing was verified and nothing was written.`) and exits 1 without printing usage. The generic unknown-argument branch still prints `err` plus `usage` exactly as the plan asks. A comment on the arm records that plan 24-07 replaces it.
- **Files modified:** `repos/security-platform/workstation/nexus-setup.sh`
- **Commit:** `dc01b0f`

**2. [Rule 3 — Blocking] `write_config()` landed in the task 2 commit rather than the task 1 commit**

- **Found during:** Task 1 verification.
- **Issue:** Task 1 asks for `write_config()` **and** for `shellcheck workstation/nexus-setup.sh` to exit 0. At that commit the function has no caller, and shellcheck 0.11.0 reports `SC2329 (info): This function is never invoked`, which makes the file non-clean. The two requirements cannot both hold at that commit.
- **Fix:** `write_config()` is defined, copied from `setup.sh` with the added `--force` handling and both "never through this function" comments, at the commit where its first caller (the pip writer) lands. Two of the four logging functions were kept in task 1 by giving them real callers there rather than by suppressing the finding: `warn()` now fires for a non-git target directory and for a `--url` path that the Docker prefix cannot carry, both of which are scaffold-level truths.
- **Files modified:** `repos/security-platform/workstation/nexus-setup.sh`
- **Commit:** `3c41ab8`

**3. [Rule 1 — Bug] `SC2094` in the `.gitignore` appender**

- **Found during:** Task 3 verification.
- **Issue:** The first version tested `[[ -s "$gi" ]]` inside a brace group already redirected `>> "$gi"` — reading and writing the same file in one construct. shellcheck flagged it, and it is a genuine ordering hazard, not a style nit.
- **Fix:** The emptiness of the existing file is captured into `need_separator` before anything is appended, and the block reads no file at all.
- **Files modified:** `repos/security-platform/workstation/nexus-setup.sh`
- **Commit:** `4bdb5e9`

### Authentication Gates

None. Nothing in this plan contacted a Nexus instance or any authenticated service; the only network the runs touched was a loopback `python3 -m http.server` stub started and stopped by the test, and two deliberately unresolvable hostnames.

## Observations for the Verifier

1. **`HELM-NOT-HANDWRITTEN` passed one commit before it should have.** At commit `3c41ab8`, before any `helm repo add` invocation existed, the check already reported PASS: its `grep -q 'helm repo add'` matched two lines of the `usage()` heredoc, which are documentation rather than an invocation and are not stripped by the gate's comment filter. The check is correct at `4bdb5e9` — the invocation is real — but its source-level half can be satisfied by prose. This is a sensitivity in the gate (plan 24-03's file), not a defect introduced here, and it is recorded rather than fixed because this plan does not own that file.
2. **`.helm/repositories.lock`** is created by Helm alongside `repositories.yaml`. The `.gitignore` entry is `.helm/`, so it is covered; no separate entry is needed.
3. **Nothing in `repos/security-platform` outside `workstation/nexus-setup.sh` was touched.** Each of the three commits' `git diff-tree --no-commit-id --name-only -r <sha>` lists exactly that one path.

## Known Stubs

**`--verify` is deliberately unimplemented in this plan** and is the reason the gate exits 1 at this commit. It is not a stub in the silent sense: the flag is recognised, refuses explicitly, writes nothing and exits non-zero, and the end-of-run report names it as the missing proof. Plan 24-07 implements it, along with the `--docker-daemon` opt-in branch selected by the operator in plan 24-04.

## Threat Flags

None. Every trust boundary this plan crosses was already in the plan's `<threat_model>`, and each of T-24-27 through T-24-33 has an implemented mitigation:

| Threat | Where it is mitigated |
|--------|----------------------|
| T-24-27 injection via `--url` | `validate_url()`, before any interpolation; rejection table in §8 above |
| T-24-28 `.npmrc` auth-token loss | `npm config set --location=project` only; no redirect onto that file exists in the source |
| T-24-29 internal hostname committed | gitignore-by-default with `--commit-config`; explicit warning when `.npmrc` is already tracked |
| T-24-30 user pip configuration replaced | warned on every run, in the generated file and in `--help`; never suggested for a shell rc file |
| T-24-31 operator's global Helm list | `HELM_REPOSITORY_CONFIG` + `HELM_REPOSITORY_CACHE` on the one `helm` invocation; checksums in §7 |
| T-24-32 plaintext index without a stated consequence | `trusted-host` only for http non-loopback, with the ADR-009 wording beside it |
| T-24-33 success reported over a routing failure | no success claim; per-ecosystem report; `--verify` named as the missing proof |

## Self-Check: PASSED

- `repos/security-platform/workstation/nexus-setup.sh` — FOUND, mode `-rw-r--r--` (not executable)
- Commit `dc01b0f` — FOUND
- Commit `3c41ab8` — FOUND
- Commit `4bdb5e9` — FOUND
