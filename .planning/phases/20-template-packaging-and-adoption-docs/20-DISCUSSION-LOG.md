# Phase 20: Template Packaging and Adoption Docs - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-14
**Phase:** 20-template-packaging-and-adoption-docs
**Areas discussed:** Reusable workflow location, Versioning/ref strategy, Docs location, Per-repo substitutions

---

## Reusable workflow location

| Option | Description | Selected |
|--------|-------------|----------|
| Copy into security_solution/.github/workflows/ | Physically add the workflow files to this repo, kept in sync with security-platform's validated version. Matches DIST-07's uses: path literally. | ✓ |
| security-platform stays canonical, adjust the uses: path | Keep the reusable workflow only in security-platform; correct DIST-07's org/repo path instead. | |
| Research it | Let phase researcher investigate GitHub's cross-repo reusable-workflow constraints. | |

**User's choice:** Copy into security_solution/.github/workflows/
**Notes:** DIST-07's literal wording (`uses: OCC-github/security_solution/.github/workflows/<name>.yml@ref`) requires the file to exist at that path — no ambiguity once read literally.

---

## Versioning / ref strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Tagged releases (@v1, @v2...) | Stable, explicit opt-in to changes. Standard practice for shared Actions workflows. | ✓ |
| Branch ref (@main) | Consumers always get latest; no opt-out on breaking changes. | |
| Claude's discretion | Follow existing SHA-pin-with-version-comment convention. | |

**User's choice:** Tagged releases (@v1, @v2...)
**Notes:** Matches the project's existing pin-with-version-comment convention (Phase 14), applied at the repo-release level.

---

## Docs location

| Option | Description | Selected |
|--------|-------------|----------|
| New standalone doc under docs/ | e.g. docs/adoption-guide.md — keeps the ~2,300-line reference doc from growing further. | ✓ |
| Append to development-security-stack-option-1.md | Keeps everything in one blueprint doc per existing structure. | |
| Claude's discretion | Follow CLAUDE.md's existing structure. | |

**User's choice:** New standalone doc under docs/
**Notes:** —

---

## Per-repo substitutions

| Option | Description | Selected |
|--------|-------------|----------|
| Nothing else — gate_mode is the only per-repo knob | The five scan jobs auto-detect repo content; no other placeholders needed. | ✓ |
| Which scan jobs to enable/disable | Template should mark job blocks as optional/removable per repo type. | |
| Branch names / protected branch | If hardcoded anywhere, needs a clear substitution point. | |

**User's choice:** Nothing else — gate_mode is the only per-repo knob
**Notes:** SC4's "which jobs apply to which repo types" is a documentation concern (guidance on removing job blocks), not a templated substitution mechanism — avoids over-engineering a config-driven job-selection system.

---

## Claude's Discretion

- Exact mechanism for keeping security-platform's workflow files in sync with the new security_solution canonical copies.
- Exact release/tagging automation (manual git tag + gh release create, vs a lightweight release workflow).
- Adoption doc's internal structure (single doc vs doc + quick-reference table).

## Deferred Ideas

None from this discussion. (Phase 19's deferred-items.md named "Phase 20" as an owner for D-19-B through D-19-E, but those are GSD-tooling quirks unrelated to this phase's domain — noted in CONTEXT.md's Deferred section but not folded into scope.)
