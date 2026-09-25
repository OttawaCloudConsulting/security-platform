# Phase 27: DefectDojo CI Auto-Import - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-25
**Phase:** 27-defectdojo-ci-auto-import
**Areas discussed:** Import job shape, Product/engagement map, Credentials and trigger, Proof and reachability

---

## Import job shape

| Option | Description | Selected |
|--------|-------------|----------|
| One import job | `defectdojo-import` job, needs all 5 scan jobs, downloads artifacts | ✓ |
| Step in each job | Import step appended to each of the 5 jobs | |
| Separate workflow | `workflow_run`-triggered workflow | |

| Option | Description | Selected |
|--------|-------------|----------|
| Opt-in via var | Runs only when `DEFECTDOJO_URL` var + token set | ✓ |
| Workflow input | `workflow_call` input, needs caller `with:` edit | |
| Always on | Always runs, warns when unconfigured | |

| Option | Description | Selected |
|--------|-------------|----------|
| Non-blocking + verify | continue-on-error import, red verify, not a required check | ✓ |
| Silent tolerate | Warning only | |
| Follow gate_mode | Blocking under `blocking` | |

| Option | Description | Selected |
|--------|-------------|----------|
| Plain curl to API v2 | No third-party action | ✓ |
| Marketplace action | Community action, SHA-pinned | |
| You decide | | |

**User's choice:** All recommended options.

---

## Product/engagement map

| Option | Description | Selected |
|--------|-------------|----------|
| One per repo | Product = `github.repository` | |
| Consumer-named | Product from caller var | ✓ |

Follow-up: unset product var → fall back to repo name (✓) vs required when enabled. Product Type → fixed default + optional var (✓) vs fixed only.

| Option | Description | Selected |
|--------|-------------|----------|
| Per branch + reimport | Engagement `ci/<branch>`, Test per tool, reimport in place | ✓ |
| One CI engagement + reimport | Single engagement for all branches | |
| New import per run | `import-scan` each run | |

| Option | Description | Selected |
|--------|-------------|----------|
| Native parsers | Tool-specific parsers, SARIF only for tflint | ✓ |
| SARIF everywhere | Generic SARIF parser | |

| Option | Description | Selected |
|--------|-------------|----------|
| auto_create_context | First run creates product/engagement | ✓ |
| Pre-created by operator | Manual setup per repo | |

Stale PR engagements: Defer to Phase 28 vs **Handle now (✓)**.

| Option | Description | Selected |
|--------|-------------|----------|
| Close on PR closed | Mark engagement Completed | |
| Delete on PR closed | DELETE engagement and findings | ✓ |
| Scheduled sweep | Separate scheduled cleanup | |

Merged vs abandoned: **Same for both (✓)**.

**Notes:** Claude added a mandatory safety guard to the delete: exact-name match only, never the default-branch engagement.

---

## Credentials and trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Add push to default branch | Scans+import on push to main | |
| PR only | Keep trigger | |
| PR + scheduled | Add scheduled default-branch run | ✓ |

Names: DEFECTDOJO_* set (✓). Secret passing: declared `workflow_call` secret (✓) vs `secrets: inherit`. Fork/Dependabot: skip cleanly (✓).

Cadence: user free text: **"Daily, 06:00 am local time"** (America/Toronto assumed).
Caller file: **New caller file (✓)** vs extend pr-security.yml.
Versioning: **Additive minor, same v1 (✓)** vs new major v2 vs per ADR-018.

---

## Proof and reachability

| Option | Description | Selected |
|--------|-------------|----------|
| Ephemeral DD in a CI run | Real Actions run against in-runner DefectDojo | ✓ |
| Local kind + act-like script | Replay curl calls locally | |
| Defer live proof to 29 | Offline gates only | |

Reachability: **Defer to Phase 29 (✓)** vs self-hosted runner vs public ingress.
TLS: Always verify vs **Opt-in insecure var (✓)**; insecure use → **warn annotation (✓)**.
Harness: **kind + Phase 26 chart (✓)** vs upstream docker-compose.
Test trigger: **Path-filtered + manual (✓)** vs manual only vs every PR.
Records: **ADR-024 + adoption guide (✓)**.

---

## Claude's Discretion

- Product Type default string, scheduled caller file name, test workflow/script names, optional CA-bundle var.
- Cleanup job placement (within D-15 constraints), import loop structure, Test titles.

## Deferred Ideas

- Homelab reachability model — Phase 29.
- Dedup settings / triage — Phase 28.
- Push-to-default-branch trigger — not chosen; revisit if needed.
- Phase 26 review warnings — separate follow-up.
