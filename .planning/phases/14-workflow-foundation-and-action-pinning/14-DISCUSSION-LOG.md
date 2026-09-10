# Phase 14: Workflow Foundation and Action Pinning - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-10
**Phase:** 14-Workflow Foundation and Action Pinning
**Areas discussed:** Placeholder job content, SHA-pin convention, Dependabot scope, Caller workflow trigger scope

---

## Placeholder job content

| Option | Description | Selected |
|--------|-------------|----------|
| actions/checkout only | Single job, single step: checkout repo, real pinned action, proves callable+caller wiring | ✓ |
| No-op echo job | One job running `echo "ok"`, zero external actions | |
| Multiple stub jobs (5 names) | 5 empty jobs named sast/iac/sca/container/secrets as placeholders | |

**User's choice:** actions/checkout only
**Notes:** Phase 15 builds the real 5 jobs from scratch; no need to pre-name stubs here.

---

## SHA-pin convention

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse exact style | `uses: actions/checkout@<sha>  # v4` matching security-platform repo | ✓ |
| Different format | Alternate comment style or placement | |

**User's choice:** Reuse exact style
**Notes:** Consistent with existing org convention in `repos/security-platform/cicd/.github/workflows/security.yml`.

---

## Dependabot scope

| Option | Description | Selected |
|--------|-------------|----------|
| github-actions only, weekly | Single ecosystem entry, weekly schedule | ✓ |
| github-actions only, daily | Same scope, faster cadence | |
| Multiple ecosystems now | Add npm/pip/terraform blocks now even though unused | |

**User's choice:** github-actions only, weekly
**Notes:** Other ecosystems don't exist in this repo's workflows yet.

---

## Caller workflow trigger scope

| Option | Description | Selected |
|--------|-------------|----------|
| pull_request, all branches | Matches ROADMAP success criteria #1 verbatim | ✓ |
| pull_request targeting main only | Restrict to PRs against main | |
| pull_request + push to main | Also run on direct pushes to main | |

**User's choice:** pull_request, all branches
**Notes:** Push trigger can be added later if needed; kept minimal for Phase 14.

---

## Claude's Discretion

- Exact filenames for the callable workflow and thin caller workflow under `.github/workflows/`.

## Deferred Ideas

- Push-to-main trigger on caller workflow.
- Additional Dependabot ecosystems (npm, pip, terraform).
- Real scan jobs (SAST/IaC/SCA/container/secrets) — Phase 15 scope.
