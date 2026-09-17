# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v2.0 — CI/CD Security Pipeline

**Shipped:** 2026-09-17
**Phases:** 10 (incl. inserted 20.1) | **Plans:** 63 | **Timeline:** ~205 days (2026-02-24 → 2026-09-17)

### What Was Built
- Callable `security.yml` workflow on `OttawaCloudConsulting/security-platform` running 5 SHA-pinned, parallel scan jobs (Semgrep SAST, Checkov IaC, SCA npm/Python/Terraform/generic Trivy, Trivy container, Gitleaks secrets)
- SARIF upload to the GitHub Security tab (6 categories) and 90-day JSON/SARIF artifact retention on every run
- Per-repo configurable gate mode (report-only default, blocking opt-in via a variable, no YAML edit)
- Branch-protection helper script (`set-required-checks.sh`) plus documented promotion path to required checks
- Both consumption modes packaged and tagged (`v1`/`v1.0.0`), with `docs/adoption-guide.md` covering preflight, both modes, gate mode, branch protection, and troubleshooting
- Live adoption on 3 external repos (2 orgs, public + private) and a live branch-protection `--apply` exercise proving GitHub actually refuses a merge on a red required check

### What Worked
- Fixture-driven validation: every claim about a scan job's behavior was backed by a real, deliberately-seeded fixture and a captured live result, not an assumption about tool behavior
- "Verify from `origin/main`, never the local tree" discipline — every merge-close plan independently re-read the remote state rather than trusting its own prior steps
- Bounded, reversible live exercises for risky changes (Phase 18's blocking-mode flip, Phase 22's required-check `--apply`) — always captured a before-state, made the change, captured the effect, then restored byte-identically
- Retroactive VERIFICATION.md backfill (Phase 20.1) caught that three early phases had shipped without independent verification and closed the gap before milestone close

### What Was Inefficient
- Phase 20.1 and Phase 21 themselves were never independently verified (no self-VERIFICATION.md) — the audit flagged this as tech debt rather than a blocking gap since their requirements were independently satisfied elsewhere
- Several plans hit the same "orchestrator's own auto-mode Bash classifier denies `gh release create` / `set-required-checks.sh --apply`" friction (20-07, 20-10) — a known interaction between GSD's auto-mode gate and irreversible `gh` commands that had to be worked around by hand each time
- DIST-08 ended PARTIAL (ADR-019 not cross-referenced in adoption-guide.md §13) — a documentation completeness gap that survived to milestone close as accepted tech debt rather than being caught earlier

### Patterns Established
- Evidence-snapshot pinning: when multiple plans within a phase all cite live API/Actions state, pin one snapshot and require every plan to cite it, rather than each re-querying independently and risking drift
- "Restore and prove byte-identical" as the closing move for any live exercise that touches shared infrastructure (branch rulesets, repo variables)

### Key Lessons
1. When a milestone's riskiest claim can't be proven without touching a real external repo, scope a dedicated late-milestone phase for it (Phase 22) rather than asserting it from local YAML — the operator-in-the-loop checkpoint at the actual write is worth the extra phase.
2. Auto-mode's Bash safety classifier will block genuinely-intended irreversible `gh`/GitHub-API commands identically to accidental ones; budget for the orchestrator running the exact recorded command by hand when this happens, and record why in the SUMMARY rather than silently retrying.
3. A milestone audit with `status: tech_debt` (not `passed`) is still closeable when it has zero `gaps` and 100% requirement satisfaction — tech debt items should be captured in STATE.md Deferred Items and PROJECT.md Known Issues, not treated as a blocker.

### Cost Observations
- Sessions: not tracked per-session in this project's STATE.md
- Notable: 63 plans across 10 phases over ~205 days, with a late-milestone insertion (20.1) and two docs-only close-out phases (21) added after the "planned" scope (20) shipped — milestone scope grew ~18% (Phases 20.1/21/22 added after Phase 20's original close) to close audit-identified gaps before shipping.

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Key Change |
|-----------|--------|------------|
| v1.0 | 9 | Workstation tooling foundation; CLI-only, no CI |
| v1.1 | 4 | Cross-platform distribution packaging replacing Homebrew-only install |
| v2.0 | 10 | First CI/CD milestone; introduced live-exercise phases, retroactive VERIFICATION.md backfill, and audit-driven gap-closure phases inserted after the "planned" roadmap shipped |

### Top Lessons (Verified Across Milestones)

1. Scope creep from audit-identified gaps (v2.0's 20.1/21/22) is legitimate and should be inserted as decimal/sequential phases rather than silently expanding an existing phase's plan count.
2. "Verify from the remote, not the local tree" is now a standing discipline across both v1.1 and v2.0 close-out plans.
