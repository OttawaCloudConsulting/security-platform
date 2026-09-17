# Phase 19: Pipeline Validation via Branch-Target PRs - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-12
**Phase:** 19-Pipeline Validation via Branch-Target PRs
**Areas discussed:** Missing fixtures (SAST/Secrets), PR lifecycle, Trace target, SAST pattern, Secrets pattern, End state

---

## Missing fixtures (SAST + Secrets)

| Option | Description | Selected |
|--------|-------------|----------|
| New fixture files | Add fixtures/vulnerable.py + a Gitleaks-triggering fixture, following existing "INTENTIONALLY VULNERABLE — DO NOT FIX" convention | ✓ |
| Seed directly in the validation PR diff | No permanent fixtures/ files — seeded findings live only on the validation branch | |

**User's choice:** New fixture files (Recommended)
**Notes:** None.

---

## PR lifecycle

| Option | Description | Selected |
|--------|-------------|----------|
| One long-lived validation PR | Single PR carries all 5 seeds, gate-mode flipped and re-run on the same PR; separate clean PR for SC4 | ✓ |
| Multiple short-lived PRs | Fresh PR per criterion | |

**User's choice:** One long-lived validation PR (Recommended)
**Notes:** None.

---

## Trace target

| Option | Description | Selected |
|--------|-------------|----------|
| New SAST finding | Trace the newly-seeded Semgrep finding | ✓ |
| Existing SCA finding | Trace an already-measured finding (e.g. minimist critical advisory) | |

**User's choice:** New SAST finding (Recommended)
**Notes:** None.

---

## SAST pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Python eval()/os.system() | fixtures/vulnerable.py, matches existing Python SCA ecosystem | ✓ |
| JS/Node pattern | fixtures/vulnerable.js using child_process.exec() | |

**User's choice:** Python eval()/os.system() (Recommended)
**Notes:** None.

---

## Secrets pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Fake AWS access key | Named Gitleaks aws-access-token rule, deterministic | ✓ |
| Generic high-entropy string | Entropy-based rule, less version-stable | |

**User's choice:** Fake AWS access key in a new fixture file (Recommended)
**Notes:** None.

---

## End state

| Option | Description | Selected |
|--------|-------------|----------|
| Revert GATE_MODE to report-only; keep fixtures permanently | Matches Phase 18 D-07 rollout sequencing | ✓ |
| Leave GATE_MODE in blocking | No revert | |

**User's choice:** Revert GATE_MODE to report-only; keep new fixtures permanently (Recommended)
**Notes:** None.

---

## Claude's Discretion

- Merge vs close of the validation PR once observations are captured.
- Exact `fixtures/README.md` table formatting for the two new fixture rows.
- Evidence format for "witnessed, not inferred" (SC2) — run URLs, `gh run view` output, etc.

## Deferred Ideas

- Branch-protection required-checks adoption (Phase 18 D-07 step 3) — stays deferred past Phase 19.
- Scan-job logic / SARIF categorization / gate-mode wiring changes — Phase 15/17/18 territory, untouched here.
- Template packaging / other-repo rollout — Phase 20.
