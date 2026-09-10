# Milestones

## v1.1 Distribution Packaging (Shipped: 2026-09-10)

**Phases completed:** 4 phases, 12 plans, 21 tasks

**Key accomplishments:**

- Cross-platform install script — 6 pinned security CLI tools (pre-commit, Trivy, Syft, Grype, Gitleaks, hadolint), checksum-verified, bash 3.2 compatible, idempotent
- Universal file-pattern hook config — one `.pre-commit-config.yaml` running only matching file types across all repos
- `workstation/setup.sh` repo bootstrapper (replaces earlier `dist/install.sh`) — single-command onboarding: install + configure + activate hooks for any git repo
- Maintenance suite — `check`/`update`/`doctor` subcommands with GitHub API version resolution, 147/147 tests passing, human-witnessed pre-commit upgrade/downgrade round trip
- Fixed dead PATH-missing warning bug (WR-01) with TDD proof
- At milestone close: live-verified all 3 outstanding human_verification gaps (phases 01, 04, 10); found and fixed a real RETURN-trap crash bug in `setup.sh` (security-platform commit `2a70c97`)

**Known deferred items at close:** 2 (see PROJECT.md "Known issues" — npm vuln drift and ESLint absence risk in `aws-zabbix-monitoring-solution`, both target-repo issues out of scope for this tooling milestone)

---
