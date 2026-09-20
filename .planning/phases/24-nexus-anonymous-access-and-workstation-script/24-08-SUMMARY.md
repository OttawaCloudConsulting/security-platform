---
phase: 24-nexus-anonymous-access-and-workstation-script
plan: 08
subsystem: docs
tags: [documentation, nexus, anonymous-access, workstation, docker, adr-009, markdownlint]

# Dependency graph
requires:
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 05
    provides: "The measured Docker handshake and realms evidence — /v2/<repo>/... 200 vs the /repository/-prefixed 404, the 3,626,020-byte layer blob, the DockerToken realm, and the 403-vs-201 write boundary"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 07
    provides: "workstation/nexus-setup.sh as shipped — the seven-flag surface, the generated-file list, the --verify status vocabulary, and the daemon-opt-in Docker branch with its A3 verdict"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 02
    provides: "The EULA/metadata boundary (PyPI simple page 200 while every component download is 403 at 192 bytes) and the provision.readiness.* wiring that made the README's honesty note stale"
  - phase: 24-nexus-anonymous-access-and-workstation-script
    plan: 01
    provides: "The top-level anonymous: values block whose helm-docs comments the README's value rows must match"
provides:
  - "kubernetes/nexus/README.md §5 — anonymous.enabled and eula.accepted stated as two independent gates, with the four client URL shapes and the Docker asymmetry"
  - "kubernetes/nexus/README.md §Limitations — the nx-anonymous wildcard scope, the anonymous repository-inventory disclosure, and the CE-ceiling consequence of removing authentication friction"
  - "workstation/README.md — the nexus-setup.sh section: flags at parity with usage(), the four-row per-ecosystem scope table, the PIP_CONFIG_FILE replacement warning, the machine-global --docker-daemon branch, and the --verify status table"
affects: [24-09, 24-10, phase-25-nexus-live-validation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A documentation edit that closes one stale claim must close its twin: the values-table row and the Limitations bullet asserting the same stale fact are one edit, not two optional ones"
    - "Quote the measured number (192 bytes, 318,961, 3,626,020, 403 vs 201) rather than describing behaviour, matching the document's existing style — and quote nothing that is not in a SUMMARY of this phase"
    - "When a literal string is forbidden by an acceptance grep but the fact it encodes is load-bearing, write the fact with a placeholder rather than dropping the fact"

key-files:
  created: []
  modified:
    - repos/security-platform/kubernetes/nexus/README.md
    - repos/security-platform/workstation/README.md

key-decisions:
  - "The new chart-README section is §5 under 'Before You Install', not a standalone heading. That section's own preamble counts its subsections ('Four properties … Read all four'), so adding a fifth meant editing the count; the alternative — a free-standing ## Anonymous Access — would have put the single most consequential install-time decision after the install command. The count prose was updated in the same edit."
  - "The daemon-mirror URL is written with a placeholder, `<NEXUS_URL>/repository/<docker-repo>`, not with the literal repository name. The plan's acceptance criterion asserts `grep -c 'repository/docker-proxy'` is 0 in workstation/README.md, while 24-07 requires the asymmetry (mirror URL carries /repository/, pull prefix does not) to be stated. Dropping the asymmetry to satisfy the grep would have removed the one fact that stops a reader 'unifying' the two shapes and breaking one. The placeholder satisfies both."
  - "The chart README never names the Docker token endpoint. It is server-advertised and lives under /repository/, so writing it would have tripped the same grep while adding nothing a consumer acts on."
  - "Two rows of the requirements table changed, not one. The acceptance grep is on the literal 'Planned (Phase 24)', which NEXUS-04 also carried; and leaving NEXUS-04 'Planned' beside a README section documenting the shipped script would have been the same defect the plan exists to fix."
  - "`anonymous.enabled`, `anonymous.userId` and `anonymous.realmName` were added to the Values table although the plan did not ask for them. The table's own preamble says it restates 'the values this wrapper owns', and 24-01 made these first-class wrapper values; a values table that omits the value the new section is about is the next stale claim."
  - "One commit for both tasks, following the 24-01 / 24-02 / 24-05 precedent and the plan's own Task 2 instruction ('Commit both README files in one commit') plus its singular-SHA acceptance criterion."
  - "requirements-completed is empty ON PURPOSE. NEXUS-02 and NEXUS-04 are marked by plan 24-10, after the work is on origin/main. Nothing was pushed."

patterns-established:
  - "Pattern: before editing a stale claim, grep the whole document for the fact it asserts — the chart README asserted 'not wired through' in two places and 'anonymous is closed' in three, and a per-line edit list misses the twin."
  - "Pattern: an ADR's governing sentence is carried at every occurrence of the directive it governs, including inside tables, not once per document."

requirements-completed: []  # NEXUS-02 and NEXUS-04 withheld on purpose — plan 24-10 marks both after merge to origin/main.

# Metrics
duration: ~35min
completed: 2026-09-20
---

# Phase 24 Plan 08: The Two Consumer-Facing Documents Summary

**The chart README and the workstation README now assert what was measured rather than what was true before this phase: five stale claims closed, two new sections written in the shape of the sections beside them, and the one Docker URL that breaks by analogy documented correctly in both documents and nowhere documented in the shape that 404s.**

## Performance

- **Duration:** ~35 min
- **Tasks:** 2 (both `auto`, no checkpoints)
- **Files modified:** 2, both in `repos/security-platform`
- **Commit:** 1 (`ee40e42`), by plan design
- **Diff:** 168 insertions, 10 deletions

## Task Commits

| Task | Commit | Subject |
|------|--------|---------|
| 1 + 2 | `ee40e42` | `docs(24-08): document anonymous access and the workstation routing script` |

`git diff-tree --no-commit-id --name-only -r ee40e42` lists exactly:

```text
kubernetes/nexus/README.md
workstation/README.md
```

Branch `feature/phase-24-nexus-anonymous-and-workstation` in `repos/security-platform`. Commit hooks ran normally; no `--no-verify`. Nothing pushed — plan 24-10 owns the PR.

## The chart README: the four edits, before and after

### 1. Requirements table

**Before**

```markdown
| NEXUS-02 | Proxy repos allow anonymous pull | Planned (Phase 24) |
| NEXUS-04 | Workstation install script points package managers at a Nexus instance | Planned (Phase 24) |
```

**After**

```markdown
| NEXUS-02 | Proxy repos allow anonymous pull | Complete (Phase 24) — **opt-in**, `anonymous.enabled`, which ships `false`; see §5 |
| NEXUS-04 | Workstation install script points package managers at a Nexus instance | Complete (Phase 24) — `workstation/nexus-setup.sh` |
```

The NEXUS-02 cell names the opt-in and its shipped default in the same breath, so the row cannot be read as "on by default". NEXUS-04 changed too — it carried the same literal, which the acceptance grep covers.

### 2. §Reaching Nexus

**Before**

> **Reads currently require authentication.** Anonymous access is closed on a default Nexus install — an unauthenticated fetch returns HTTP 401 — and this chart does not open it. Opening read-only anonymous pull is NEXUS-02, a Phase 24 decision to take deliberately.

**After**

> **Reads require authentication by default.** Anonymous access is closed on a default Nexus install — an unauthenticated fetch returns HTTP 401 — and this chart ships it closed. Setting `anonymous.enabled: true` opens unauthenticated read (NEXUS-02); it is an explicit opt-in, and it is not sufficient on its own, because `eula.accepted` is a second, independent gate — see §5.

The parenthetical about `nexus3.config.enabled` and the subchart's Groovy Job is kept verbatim and extended by one clause naming it as the reason `anonymous.enabled` is a top-level value of this wrapper.

**One edit beyond the plan's list, in the same paragraph** (the sentence immediately above it, which is the source of the Docker trap):

- Before: "the proxy repositories are served under `/repository/<name>/`" — true of three of the four.
- After: "the npm, PyPI and Helm proxies are served under `/repository/<name>/` … **The Docker proxy is the exception** — it is served directly under the host with no `/repository/` segment, and the analogous URL returns `404`."

### 3. §Limitations and Notes

**Before**

```markdown
- **Anonymous pull is not open.** Clients authenticate with the admin credential. NEXUS-02 covers read-only anonymous access in Phase 24.
- **`provision.readiness.attempts` and `provision.readiness.intervalSeconds` are not read at run time.** …
```

**After** — three bullets replacing the first, and the second bullet deleted as the twin of edit 4:

- the `nx-anonymous` role is built in, `readOnly: true`, carries `nx-repository-view-*-*-read` and `nx-repository-view-*-*-browse` (wildcards on **both** format and repository name), therefore covers repositories created later, and cannot be narrowed in place — the remedy being a custom role bound to the anonymous user, out of scope here;
- `GET /service/rest/v1/repositories` answers `200` anonymously, disclosing every repository's **name, format, type and URL**, and explicitly *not* remote URLs and *not* credentials;
- the CE ceiling (40,000 components / 100,000 requests per day) with the observation that removing authentication friction makes the instance easier to point CI at, spending that budget without anyone holding a credential.

The `docker.pathEnabled` bullet was also corrected — a Rule 1 deviation, below.

### 4. The `provision.readiness.*` values rows

**Before**

```markdown
| `provision.readiness.attempts` | `60` | Readiness poll attempts. **Not wired through today** — see Limitations. |
| `provision.readiness.intervalSeconds` | `10` | Seconds between poll attempts. **Not wired through today** — see Limitations. |
```

**After**

```markdown
| `provision.readiness.attempts` | `60` | Readiness poll attempts against `/service/rest/v1/status/writable`. Reaches `files/provision.sh` as `READY_ATTEMPTS` through the Job env; the script supplies no default. |
| `provision.readiness.intervalSeconds` | `10` | Seconds between poll attempts, reaching `provision.sh` as `READY_INTERVAL`. The **product** of the two must stay inside `provision.activeDeadlineSeconds` — 60 × 10s = 10 minutes, inside 900. |
```

Wording matched to the shipped `values.yaml` helm-docs comments as plan 24-02 left them, including the `activeDeadlineSeconds` ceiling sentence.

### 5. The new section (§5, "Anonymous read is an explicit opt-in, and it is not the only gate")

Modelled on §2's shape — name the value, the measured symptom, the one-line fix. It states in the same breath:

- `anonymous.enabled` ships `false`; `true` opens unauthenticated read (`PUT /service/rest/v1/security/anonymous` → `200`);
- **both gates**: `anonymous.enabled: true` with `eula.accepted: false` gives metadata `200` (an unauthenticated PyPI simple page at its full **76,776** bytes) and **`403` on every component download with a 192-byte body**, named as the most likely "it doesn't work" report — with the 24-02 corollary that a `200` from `/simple/<project>/` proves anonymous read is open and proves *nothing* about the licence, so the evidence must be a component download (npm tarball, a PyPI file under `/packages/`, or the Helm `index.yaml`, which Nexus treats as a component). With both `true`, the identical npm fetch is `200` and **318,961** bytes;
- the write boundary: anonymous `POST` of a valid repository body is exactly `403` and creates nothing; the same body with the admin credential is `201`;
- `DockerToken` is appended **unconditionally**, not as part of the anonymous opt-in, because a bearer token issued to the **admin** user is also rejected `401` on the manifest request when that realm is inactive — it governs Docker bearer validation generally rather than anonymity;
- the four URL shapes as a table, with Docker's row carrying "**no `/repository/` segment**", the `/v2/` explanation, the measured `200`-vs-`404` pair, a real `docker pull localhost:8081/docker-proxy/library/alpine:3.21`, and the five-leg handshake evidence ending at the **3,626,020**-byte `linux/amd64` layer blob.

## The workstation README

A new `## Routing a Repository Through Nexus (`nexus-setup.sh`)` section, placed after §On-Demand Security CLI Tools and before §Version Management so the `setup.sh` narrative (Quick Start → Prerequisites → What Gets Installed → hooks → secrets → on-demand tools) stays intact, and a `nexus-setup.sh` row appended to §Contents — which enumerates this directory's files and was false without it.

Contents, in the Quick Start style:

- **Invocation** with the explicit interpreter, stating that the script is deliberately not executable (the project Script Safety rule).
- **Flags** — a seven-row table, plus the three `NEXUS_VERIFY_*` sample-artefact overrides and the `--force-update` re-run property.
- **Files written** — `.npmrc`, `pip.conf`, `.helm/repositories.yaml`, `.helm/cache/`, `.nexus-env` (naming its four exports), `.gitignore`.
- **The per-ecosystem scope table**, four rows, each answering "needs `source .nexus-env`?": npm **No** (native project scope); pip **Yes** (`PIP_CONFIG_FILE` is the mechanism, no project scope exists); Helm **Yes** (`HELM_REPOSITORY_CONFIG`); Docker **no per-repository mechanism of any kind**, prefix string only, manual edit of an image reference. The section leads with the sentence that three of four do not route until a file is sourced.
- **The `PIP_CONFIG_FILE` warning** — it *replaces* rather than adds to the user scope (measured: `pip config list -v` lists neither user-scope variant), so a corporate CA bundle or an extra index URL stops applying in that shell; source per shell session; **never** in a shell rc file, with the reason (it would be the global workstation default REQUIREMENTS.md puts out of scope).
- **`trusted-host`** — emitted only for plain HTTP to a non-loopback host, with the ADR-009 warning and removal requirement.
- **`--docker-daemon`** — the `daemon-opt-in` branch as shipped: machine-global and contrasted explicitly with the per-repository npm/pip/Helm configuration; the two keys named with when each is written; `docker.io`-only mirroring spelled out; the mirror-URL asymmetry with its measured justification; the timestamped backup path and the `cp` restore command; at-most-once append preserving mirror priority; malformed JSON never overwritten; **engine restart required and never performed by the script**.
- **`--verify`** — the five-status table (`ok`, `FAILED`, `UNVERIFIABLE`, `SKIPPED`, `MANUAL`), the three server-side diagnoses each naming the responsible value, that anything but `ok`/`MANUAL` exits non-zero, that **a `MANUAL` docker row is expected rather than a failure**, and the 24-07 hand-forward: `UNVERIFIABLE` counts as a failure, so a repository with no `package.json` exits 1 on the npm row — remedy `npm init -y`.
- **Gitignoring** — the four default entries, `--commit-config` as the opt-out, and the consequence of committing (broken resolution for contributors who cannot reach the host; internal-hostname disclosure if public).

### Flag parity against `usage()`

`bash workstation/nexus-setup.sh --help`, option lines only:

```text
--commit-config
--docker-daemon
--force
--url
--verify
-h, --help
-v, --verbose
```

Every one of the seven appears in the README, and the README introduces no eighth. The only other `--`-prefixed tokens in the new section belong to **other tools** and are attributed to them in the sentence that carries them: `--force-update` (`helm repo add`, quoted from the script's own usage), `--location=project` (`npm config set`), `-y` (`npm init`), `-v` (`pip config list -v`).

## Verification

```text
pre-commit run --files kubernetes/nexus/README.md          -> markdownlint Passed, exit 0
pre-commit run --files workstation/README.md kubernetes/nexus/README.md -> markdownlint Passed, exit 0
bash scripts/check-nexus-chart.sh                          -> PASS - 18 checks, 0 failures (exit 0)
```

Acceptance greps, all measured after the commit:

| Grep | File | Count | Required |
|---|---|---|---|
| `Planned (Phase 24)` | chart README | **0** | 0 |
| `Anonymous pull is not open` | chart README | **0** | 0 |
| `Reads currently require authentication` | chart README | **0** | 0 |
| `repository/docker-proxy` | chart README | **0** | 0 |
| `repository/docker-proxy` | workstation README | **0** | 0 |
| `anonymous.enabled` | chart README | 8 | ≥ 1, with `eula.accepted` |
| `eula.accepted` | chart README | 7 | ≥ 1 |
| `nx-anonymous` | chart README | 1 | present in §Limitations |

`trusted-host` / `insecure-registries` occurrences in the workstation README were listed and each inspected: four hits (two headings/prose, one table cell, two warning paragraphs). Every one either *is* the ADR-009 warning sentence or sits immediately beside it; the table cell carries the removal clause inline as well as pointing at the full warning below.

## Every number quoted, and where it comes from

| Number | Where used | Source |
|---|---|---|
| 192 bytes | both documents | 24-02-SUMMARY (licence refusal body), 24-07-SUMMARY |
| 76,776 bytes | chart README §5 | 24-02-SUMMARY (PyPI simple page under an unaccepted EULA) |
| 318,961 bytes | chart README §5 | 24-02-SUMMARY, reproduced in 24-07-SUMMARY §1b |
| 3,626,020 bytes | chart README §5 and §Limitations | 24-05-SUMMARY (`linux/amd64` layer blob) |
| 403 / 201 | chart README §5 | 24-05-SUMMARY (anonymous vs admin POST) |
| 200 / 404 Docker path pair | both documents | 24-05-SUMMARY `DOCKER-PATH-SHAPE` |
| 401 on the admin bearer token | chart README §5 | 24-05-SUMMARY, `values.yaml` comment |
| 40,000 / 100,000 | chart README §Limitations | pre-existing §4, `values.yaml` comment |
| 60 × 10s = 10 min inside 900 | chart README values table | 24-02-SUMMARY, `values.yaml` |
| `20260920T192802Z` backup name | workstation README | 24-07-SUMMARY §2b (illustrative stamp, shown as an example path) |

No number appears in either document that is not in this table.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] The `provision.readiness.*` Limitations bullet was the twin of the values-table row and had to go with it**

- **Found during:** Task 1.
- **Issue:** the plan names the values-table row (edit 4) but not the §Limitations bullet, which asserts the same stale fact at greater length ("are not read at run time … The provisioning script hard-codes 60 attempts at 10-second intervals"). Fixing only the row would have left the document contradicting itself two screens apart, and the row's own "see Limitations" pointer aimed at the contradiction.
- **Fix:** the bullet is deleted and its surviving content (the 10-minute budget, the 900-second deadline) folded into the values-table row, which is where a reader looking for a value's behaviour goes.
- **Files modified:** `repos/security-platform/kubernetes/nexus/README.md`
- **Commit:** `ee40e42`

**2. [Rule 1 — Bug] The `/repository/<name>/` generalisation in §Reaching Nexus is the source of the Docker trap**

- **Found during:** Task 1.
- **Issue:** the sentence above the passage the plan asked me to rewrite says the proxy repositories "are served under `/repository/<name>/`" without qualification. That is the exact analogy 24-05 measured as a `404` for Docker. Documenting the correct shape in §5 while leaving the false generalisation in the section a reader hits first would have left the trap in place.
- **Fix:** the sentence now names npm, PyPI and Helm, states the Docker exception and its `404`, and points at §5.
- **Files modified:** `repos/security-platform/kubernetes/nexus/README.md`
- **Commit:** `ee40e42`

**3. [Rule 1 — Bug] The `docker.pathEnabled` Limitations bullet was stale after 24-05**

- **Found during:** Task 1.
- **Issue:** the bullet says "An actual `docker pull` through it needs ingress and TLS, which is Phase 25 work; the repository definition itself is verified." 24-05 measured the full anonymous OCI handshake and a 3.6 MB layer blob through that repository, so "the repository definition itself is verified" now understates what is known — and understating measured evidence in a document whose argument is "measured, not asserted" is the same defect as overstating it.
- **Fix:** the bullet now states that the protocol is measured, links the no-`/repository/` URL shape to `docker.pathEnabled` (which is *why* the shape is what it is), and narrows the Phase 25 residual to what it actually is: a pull executed by a real `dockerd` against a real hostname with ingress and TLS. The NetworkPolicy bullet beside it was not touched.
- **Files modified:** `repos/security-platform/kubernetes/nexus/README.md`
- **Commit:** `ee40e42`

**4. [Rule 2 — Missing critical] The Values table had no `anonymous.*` rows**

- **Found during:** Task 1.
- **Issue:** the table's own preamble says it restates "the values this wrapper owns". Plan 24-01 made `anonymous.enabled`, `anonymous.userId` and `anonymous.realmName` first-class wrapper values; a values table that omits the value the new section is entirely about is the next stale claim someone files a bug against.
- **Fix:** three rows added directly after `eula.accepted`, worded from the shipped `values.yaml` helm-docs comments, with `anonymous.enabled` naming its independence from `eula.accepted` and pointing at §5 and §Limitations.
- **Files modified:** `repos/security-platform/kubernetes/nexus/README.md`
- **Commit:** `ee40e42`

**5. [Rule 3 — Blocking] The `Four properties … Read all four` count prose**

- **Found during:** Task 1.
- **Issue:** the new section is §5 of a numbered sequence whose introduction counts its own subsections twice in one sentence.
- **Fix:** both counts updated to five in the same edit. The alternative — a free-standing `## Anonymous Access` heading — was rejected because it would have placed the most consequential install-time decision *after* the install command.
- **Files modified:** `repos/security-platform/kubernetes/nexus/README.md`
- **Commit:** `ee40e42`

**6. [Rule 3 — Blocking] The mirror URL versus the acceptance grep**

- **Found during:** Task 2.
- **Issue:** a direct collision between two of the plan's own requirements. Task 2 says "name the keys written" for the daemon branch, and 24-07's `VERDICT: A3-FALSIFIED-CANDIDATE-1` makes the mirror URL's `/repository/` segment load-bearing — it is the measured difference between a mirror that stores components and one that pulls layers and stores nothing. But the plan's acceptance criterion asserts `grep -c 'repository/docker-proxy'` is **0** in that file.
- **Fix:** the mirror URL is written as `<NEXUS_URL>/repository/<docker-repo>`, a placeholder, and the asymmetry is stated in prose exactly as 24-07 puts it, including the measured consequence of the alternative candidate (pull exits 0, zero components stored) and the warning that unifying the two shapes breaks one. The fact survives; the literal does not. The same care was applied to the chart README, which deliberately never names the Docker **token endpoint** — server-advertised, lives under `/repository/`, and not a thing a consumer acts on.
- **Files modified:** `repos/security-platform/workstation/README.md`
- **Commit:** `ee40e42`

**7. [Rule 2 — Missing critical] The `## Contents` table did not list `nexus-setup.sh`**

- **Found during:** Task 2.
- **Issue:** that table enumerates this directory's files. The script has been in the tree since 24-06; the table was already false and would have stayed false in a commit whose entire subject is documenting the script.
- **Fix:** one row appended.
- **Files modified:** `repos/security-platform/workstation/README.md`
- **Commit:** `ee40e42`

### Authentication Gates

None. This plan made no network request and touched no credential.

---

**Total deviations:** 7 auto-fixed (3 bugs, 2 missing critical, 2 blocking). None changes what either document claims about measured behaviour; all seven close a stale or missing claim the plan's own success criteria ("no document claims routing that requires an unstated manual step", "both documents describe measured behaviour") would otherwise have left open.

## Observations for the Verifier

1. **`requirements-completed` is empty on purpose.** The plan's own Task 2 says so — "`requirements-completed: []`; plan 24-10 marks both IDs" — and the README rows nonetheless read "Complete (Phase 24)", which is the *chart's* delivery status on this branch, not the REQUIREMENTS.md tracking state. `requirements.mark-complete` was **not** run, and `.planning/REQUIREMENTS.md` is untouched.
2. **Nothing was pushed.** 24-10 owns the PR.
3. **The mirror-URL placeholder is a deliberate reading of a conflicting acceptance criterion**, recorded in deviation 6. A verifier grepping for the literal will find zero, as required; a verifier reading for the *fact* will find it stated with a placeholder.
4. **The chart README's §5 forward-references §Limitations and vice versa.** Both anchors are plain prose ("see §5", "see Limitations"), not markdown anchors, matching the document's existing cross-reference style (§2/§4 do the same).
5. **`docs/development-security-stack-option-1.md` and `docs/ARCHITECTURE_AND_DESIGN.md` were not touched** — 24-PATTERNS.md records a verified no-op there (`grep -i anonymous` → zero matches), so no CLAUDE.md diagram/matrix preservation rule is engaged.

## Known Stubs

None. Both documents describe behaviour that is implemented and measured; nothing in either is marked "coming soon", "planned" or "TODO", and the only forward-looking claims name Phase 25 as the owner of a residual that 24-05 and 24-07 explicitly did not close (a `dockerd`-executed pull against a real hostname with TLS).

## Threat Flags

None. This plan creates no network endpoint, no auth path and no schema. All five `mitigate` dispositions in its `<threat_model>` are implemented:

| Threat | Where it is mitigated | Evidence |
|--------|----------------------|----------|
| T-24-40 undocumented all-repository anonymous read | chart README §Limitations bullet 1 | `nx-anonymous`, `readOnly: true`, both wildcard privileges, the future-repository consequence, and the custom-role remedy |
| T-24-41 undocumented repository inventory endpoint | chart README §Limitations bullet 2 | `GET /service/rest/v1/repositories` → 200, with its exact bounds (name/format/type/URL; not remote URLs, not credentials) |
| T-24-42 a documented pull URL that 404s | both documents | `grep -c 'repository/docker-proxy'` = 0 in both; the token endpoint is never named; only the measured-working shape appears, with a real `docker pull` example |
| T-24-43 plaintext directives without their removal condition | workstation README | ADR-009 removal sentence at every `trusted-host` and `insecure-registries` occurrence, table cell included |
| T-24-44 a machine-global change documented as per-repository | workstation README `--docker-daemon` | machine-global stated in the section's second sentence and contrasted with npm/pip/Helm; the scope table's Docker row says no per-repository mechanism exists |

## Self-Check: PASSED

- `repos/security-platform/kubernetes/nexus/README.md` — FOUND (197 → 233 lines)
- `repos/security-platform/workstation/README.md` — FOUND (180 → 302 lines)
- Commit `ee40e42` — FOUND in `repos/security-platform`, `git diff-tree` lists exactly the two `key-files.modified` paths
- `pre-commit run --files workstation/README.md kubernetes/nexus/README.md` — exit 0 after the commit
- `bash scripts/check-nexus-chart.sh` — `PASS - 18 checks, 0 failures`, exit 0 after the commit
