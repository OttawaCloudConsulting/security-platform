## What this adds

### Server side — NEXUS-02 (proxy repos allow anonymous pull)

- A wrapper-owned top-level `anonymous:` block in `kubernetes/nexus/values.yaml` (`enabled`, `userId`, `realmName`), wired through `templates/job-provision.yaml` into the provisioning Job as `ANONYMOUS_ENABLED` / `ANONYMOUS_USER_ID` / `ANONYMOUS_REALM_NAME`.
- `kubernetes/nexus/files/provision.sh` gains two steps before the repository upsert: step 3, an **unconditional** `PUT /service/rest/v1/security/anonymous` (200); step 4, a **guarded** append of `DockerToken` to the active realms list (204, at-most-once, both sides normalised through `jq -c` before comparison).
- `provision.readiness.attempts` / `intervalSeconds` stopped being decorative — they now reach `provision.sh` and change its behaviour, closing a Phase 23 deferred item.
- `scripts/check-nexus-chart.sh` went 17 → 18 checks: the old `ANONYMOUS-NOT-OPENED` check was **inverted** into `ANONYMOUS-VALUE-PRESENT` (proves the value is wired by toggling it across two renders) and `ANONYMOUS-DEFAULT` (proves the shipped default is `false`) was added.
- `scripts/nexus-live-smoke.sh` went 13 → 25 live checks, adding anonymous pull for npm, PyPI and Helm (three verdicts each: transport / HTTP status / byte count), the full Docker client handshake, the realm state readback, the Docker URL shape, and the anonymous write refusal.

### Workstation side — NEXUS-04 (per-repo routing script)

- `workstation/nexus-setup.sh` (1,637 lines, mode 644, never executable) points one repository's npm, pip and Helm clients at a given Nexus: `.npmrc` merged via `npm config set --location=project` (a pre-existing auth-token line survives byte-identically), `pip.conf`, `helm repo add --force-update`, and one sourceable `.nexus-env` exporting exactly four variables. Generated files are gitignored by default.
- `--verify` is a real proof pass: per ecosystem it reads the configuration back **from the client** and then fetches a real component through it, with cache disabled. It separates three server-side conditions by the value responsible — transport failure (unreachable), HTTP 401 (`anonymous.enabled`), HTTP 403 with a body under ~1,000 bytes (`eula.accepted`) — reports Docker as `MANUAL` under every condition, and exits non-zero when any row is not `ok`. A skip is not a pass.
- `--docker-daemon` is off by default and writes `~/.docker/daemon.json` (timestamped backup, `jq` merge that preserves order) only when asked. `insecure-registries` is emitted only for a plain-`http` `--url`, per ADR-009.
- `scripts/check-nexus-setup.sh` (747 lines) is its offline gate: twelve checks, six source-level hazard checks plus six behavioural checks that run the subject inside throwaway `git init` repos.

### Documentation

`kubernetes/nexus/README.md` gains a §5 "Anonymous access" under *Before You Install* (two independent gates: `anonymous.enabled` and `eula.accepted`), the four client URL shapes, the Docker asymmetry, and three Limitations bullets. `workstation/README.md` gains the `nexus-setup.sh` section at flag parity with `usage()`. ADR-021 is recorded in the consuming documentation repository, not here.

## This supersedes PR #14's out-of-scope statement

PR #14 (Phase 23) said, under *Explicitly out of scope*: **"Anonymous pull is deliberately NOT enabled by this PR (NEXUS-02). It belongs to the follow-on hardening phase, along with the Checkov-coverage decision above and the still-inert `provision.readiness.*` values keys."**

This PR **is** that follow-on. That sentence is superseded by this PR on all three counts — anonymous pull, the Checkov-coverage decision (accepted and documented, see residual risk 4) and the `provision.readiness.*` keys (now wired). PR #14 is not edited; it is a merged record of what was true when it was written.

## The shipped default is closed

`anonymous.enabled` ships **`false`**. A public chart must not open unauthenticated read for anyone who installs it without reading the values file. Enabling it is an explicit consumer opt-in, and the value carries its own consequences inline.

## Why the `DockerToken` realm is activated unconditionally

The `DockerToken` realm governs Docker **bearer-token validation in general**, not anonymous access specifically: without it an **admin-issued** Docker token is also rejected `401`, so gating the realm on `ANONYMOUS_ENABLED` would leave `docker-proxy` broken at the shipped default. The anonymous `PUT` is likewise unconditional, in the other direction — it must be able to **close** access that a previous install or a human opened.

## Measured evidence

### Offline gates, on the branch tip

| Gate | Verdict |
|------|---------|
| `bash scripts/check-nexus-chart.sh` | `PASS - 18 checks, 0 failures` |
| `bash scripts/check-nexus-setup.sh` | `ALL PASS - 12 check(s) executed and passed; 0 sub-check(s) skipped` |
| `pre-commit run --all-files` | exit 0 (ruff, ruff-format, shellcheck, yamllint, markdownlint all pass) |

### Live gate, on the branch tip

`bash scripts/nexus-live-smoke.sh` — `ALL PASS - 25 live check(s) executed and passed; 0 sub-check(s) skipped (not passed).` (exit 0; docker half and `kind` half both green)

The script boots a real `sonatype/nexus3:3.96.0-ubi` container, runs the chart's own provisioning script against it **twice** (a repeat blind POST returns 400, so a second exit 0 is the only proof the upsert is idempotent), then installs the chart on a throwaway `kind` cluster.

### Anonymous pull, measured in bytes

Every fetch below carries no `-u` and no `-K -`. Each ecosystem asserts three separate verdicts so that a transport error, a wrong status and a refusal body are three distinguishable failures and none can mask another. The floors are derived from the measured size under a stated rule (at least 10× the 192-byte EULA refusal body; at most half the measured size).

| Ecosystem | Artefact | Status | Measured bytes | Floor |
|-----------|----------|--------|----------------|-------|
| npm | package tarball | 200 | 318,961 | 100,000 |
| PyPI | per-project simple page | 200 | 76,776 | 20,000 |
| Helm | `index.yaml` | 200 | 291,818 | 100,000 |
| Docker | `linux/amd64` layer blob | 200 | 3,626,020 | 1,000,000 |

The Docker row is the **full five-leg client handshake**: `/v2/` → 401 with a `WWW-Authenticate` challenge (parsed, never hardcoded) → token → manifest index with `Authorization: Bearer` → 200 → the `linux/amd64` child manifest selected **by platform**, not by array position → layer blob. A header-less manifest `GET` returns 200 even with the realm removed; that fact is written into the gate as the thing that must never be accepted as evidence.

Two further boundaries were measured, not assumed:

- **Path shape.** `/v2/<repo>/…` is 200 and `/v2/repository/<repo>/…` is 404, both unauthenticated. The URL that looks right by analogy is the one that fails.
- **The EULA is not the anonymous gate.** Under `eula.accepted=false` the PyPI simple page still returns 200 with all 76,776 bytes, while the npm tarball and the Helm `index.yaml` return 403 with a 192-byte refusal. The EULA covers **component** downloads; a PyPI simple page is **metadata**. Nexus treats the Helm `index.yaml` as a component, which is the opposite of the PyPI result.
- **Read does not extend to write.** An unauthenticated `POST` of a structurally valid npm-proxy body is exactly 403 and creates nothing — and the admin `GET` that proves non-creation is itself proven, by returning 200 for a repository that does exist.

### Assumption A3 — can a path-routed Nexus be a Docker daemon mirror?

`VERDICT: A3-FALSIFIED-CANDIDATE-1`, measured in a Docker-in-Docker probe pinned by digest to the **exact** host engine version (moby v28.3.2), scored on the server-side component delta rather than on the client's exit code, with two controls per candidate:

- `registry-mirrors` at `<host>/repository/<docker-repo>` **routes** (components 0 → 1).
- `registry-mirrors` at `<host>/<docker-repo>` **does not route**, and the `docker pull` still exits 0 — Docker falls back to Docker Hub silently.
- `registry-mirrors` never touches a non-Docker-Hub reference at all, confirmed from version-matched moby source.

So the `/repository/` segment is **required** in the mirror URL and **forbidden** in the image reference. The intuitive shape is the wrong one and it fails silently. This is the branch that shipped: `--docker-daemon`, off by default, writing exactly the measured pair.

## Residual risks a reviewer should weigh

1. **Anonymous read covers every repository, including ones created later.** Access comes from Nexus's built-in `nx-anonymous` role, which carries `nx-repository-view-*-*-read` and `nx-repository-view-*-*-browse`. The role is `readOnly: true` and cannot be narrowed in place; this chart neither creates nor edits a role. A hosted repository added after the fact is world-readable from the moment it is created. *(Related: removing authentication friction also makes the Community Edition 40,000-component / 100,000-request-per-day ceilings easier to reach.)*
2. **The repository inventory is anonymously readable.** `GET /service/rest/v1/repositories` answers 200 without credentials, disclosing every repository's name, format, type and URL. It does **not** disclose remote URLs and does **not** disclose credentials.
3. **There is no TLS in front of Nexus until Phase 25.** Anonymous traffic — and anything else a consumer sends — crosses the network in plaintext. Both plaintext directives this work can emit (`pip --trusted-host`, Docker `insecure-registries`) are conditional on a plain-`http` URL and carry ADR-009's removal sentence.
4. **CI's Checkov provides zero coverage of this chart.** 24 latent findings (5 wrapper, 19 subchart), none of which reach CI. This is accepted and documented, not solved: both alternatives create a second artefact that drifts by construction, and the `required` credential guard was deliberately not weakened to make the chart scannable.

## Commits on this branch

13 commits, from seven plans:

| Plan | Commits | Touches |
|------|---------|---------|
| 24-01 | `1266279` | values, Job template, `provision.sh`, both gate scripts |
| 24-02 | `07c74e2` | live smoke, `provision.sh`, Job template, values |
| 24-03 | `f008707`, `41c2e6a` | `scripts/check-nexus-setup.sh` |
| 24-05 | `9b670c4` | live smoke |
| 24-06 | `dc01b0f`, `3c41ab8`, `4bdb5e9` | `workstation/nexus-setup.sh` |
| 24-07 | `c1df999`, `ec9544d`, `9ec38b6` | `workstation/nexus-setup.sh` |
| 24-08 | `ee40e42`, `c3ba864` | both READMEs |

Plans 24-04 (the A3 measurement) and 24-09 (ADR-021) produced no commit here — their artefacts live in the consuming documentation repository.

Nine files changed: 3,440 insertions, 83 deletions.

## Gates run before opening this PR

All four green on the branch tip, with no `--no-verify` anywhere. The `gitleaks` hook runs at `stages: [pre-push]`, so `pre-commit run --all-files` does not reach it; it was additionally run at its own stage against this exact push range (`--from-ref origin/main --to-ref HEAD`) and passed, and it runs again for real on the push.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01FKhf6VmaBFhZGJK9WcLawZ
