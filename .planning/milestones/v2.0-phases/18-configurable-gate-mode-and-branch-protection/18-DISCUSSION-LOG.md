# Phase 18: Configurable Gate Mode and Branch Protection - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-11
**Phase:** 18-configurable-gate-mode-and-branch-protection
**Areas discussed:** Flag granularity & shape, Severity threshold semantics, Branch protection required-checks scope, Default value & rollout safety

---

## Flag granularity

| Option | Description | Selected |
|--------|-------------|----------|
| Single global flag | One flag controls all 5 jobs uniformly | ✓ |
| Per-job flags | Independent flag per scan job | |

**User's choice:** Single global flag.

---

## Flag shape

| Option | Description | Selected |
|--------|-------------|----------|
| String enum | `gate_mode: 'blocking' \| 'report-only'` | ✓ |
| Boolean | e.g. `blocking: true/false` | |

**User's choice:** String enum.

---

## Flag name

| Option | Description | Selected |
|--------|-------------|----------|
| `gate_mode` | Matches roadmap's own wording | ✓ |
| `security_gate` | More explicit but longer | |

**User's choice:** `gate_mode`.

---

## Severity threshold semantics

| Option | Description | Selected |
|--------|-------------|----------|
| Any finding fails | Blocking flips continue-on-error off; native tool exit codes decide | ✓ |
| Severity-cutoff gating | gate_mode also carries a severity floor | |

**User's choice:** Any finding fails. **Notes:** pip-audit has no severity field, ruling out consistent severity-cutoff wiring across all five jobs.

---

## Branch protection required-checks scope

| Option | Description | Selected |
|--------|-------------|----------|
| Job-level checks only | The six `security / X` checks | ✓ |
| Both job-level and code-scanning checks | All twelve check names | |

**User's choice:** Job-level checks only. **Notes:** Code-scanning Security-tab UI visibility was left unconfirmed in Phase 17 (17-07-SUMMARY.md open item).

---

## Default value & rollout safety

| Option | Description | Selected |
|--------|-------------|----------|
| Default report-only + explicit warning | Unset = report-only; doc sequences check-visibility confirmation before flipping to blocking before adding required checks | ✓ |
| Default blocking, no warning | Unset = blocking (secure-by-default) | |

**User's choice:** Default report-only + explicit warning.

---

## Claude's Discretion

- Exact GitHub Actions expression syntax for conditionally setting `continue-on-error` per scan step based on `gate_mode`.
- How the copy-paste consumption mode reads `gate_mode` (`vars.gate_mode` vs `env:` block).
- Exact wording/location of the new branch-protection doc (new file, ADR, or section in `development-security-stack-option-1.md`).

## Deferred Ideas

- Severity-cutoff gating — deferred, inconsistent across tools (pip-audit has no severity field).
- Requiring code-scanning-per-driver checks — deferred until Security-tab UI visibility is confirmed.
- Per-job gate flags — deferred; roadmap describes one flag.
- Full template-packaging/copy-paste rollout guidance for other repos — explicitly Phase 20's job.
