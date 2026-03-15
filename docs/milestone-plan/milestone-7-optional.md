# Milestone 7: Optional Enhancements

## Goal

Extend the stack with additional capabilities that complement but are not required by the core security program: code quality metrics (SonarQube), a purpose-built container registry (Harbor), and commit-level integrity (Git commit signing). Each feature is independently deployable — adopt any combination based on need.

## Prerequisites

- M4 complete (DefectDojo running — SonarQube and Harbor findings feed into it)
- M5 complete (hardening in place — optional services should deploy into a hardened environment)

## Features

| ID | Feature | Components |
|----|---------|------------|
| M7-F1 | SonarQube Community Build [optional] | Helm chart `sonarqube/sonarqube`, quality gates, DefectDojo import |
| M7-F2 | Harbor Container Registry [optional] | Helm chart `harbor/harbor`, scan-on-push, robot accounts |
| M7-F3 | Commit signing [optional] | SSH key signing, Git config, GitHub verification |

---

### M7-F1: SonarQube Community Build [Optional]

**Delivers:** Code quality metrics beyond what security scanners provide — complexity, duplication, maintainability, test coverage, bug detection, and quality gates.

**Key Components:**

- Helm chart: `sonarqube/sonarqube`
- Namespace: `sonarqube`
- Resource requirements: 2 Gi RAM, 1 core, 10 Gi storage
- SonarLint IDE integration (VS Code / JetBrains) for real-time feedback
- DefectDojo import via "SonarQube Scan" parser
- Limitation: Community Build supports single-branch analysis only — no PR decoration (paid feature)

**Done Criteria:**

- `kubectl get pods -n sonarqube` shows SonarQube pods running
- SonarQube UI accessible at `http://localhost:9000` via port-forward
- Default admin password changed from `admin`
- At least one project analyzed: `sonar-scanner` run against a repository
- Quality gate configured with thresholds for new code (e.g., no new bugs, coverage above X%)
- Results imported to DefectDojo via the "SonarQube Scan" parser
- `sonarqube-values.yaml` committed to infrastructure repository

**Dependencies:** M4-F1 (DefectDojo for finding aggregation), M5-F1 (NetworkPolicy for `sonarqube` namespace).

---

### M7-F2: Harbor Container Registry [Optional]

**Delivers:** A purpose-built container registry with scan-on-push, image signing support, tag retention policies, and robot accounts for CI credentials — complementing Nexus (which handles non-container package types).

**Key Components:**

- Helm chart: `harbor/harbor`
- Namespace: `harbor`
- Resource requirements: 2 Gi RAM, 1 core, 50 Gi+ storage
- Built-in Trivy scanning on every image push
- Tag retention policies for automatic cleanup of old images
- Robot accounts for CI/CD credentials (replacing long-lived user credentials)
- Replication capability for multi-registry scenarios

**Done Criteria:**

- `kubectl get pods -n harbor` shows all Harbor pods running
- Harbor UI accessible at `https://localhost:8443` via port-forward
- Admin password changed from the Helm-configured default
- A project created in Harbor for the target application
- A container image pushed to Harbor triggers an automatic Trivy scan (visible in Harbor UI > project > repository > image > Vulnerabilities tab)
- A robot account created for CI/CD image push operations
- Tag retention policy configured (e.g., keep last 10 tags per repository)
- `harbor-values.yaml` committed to infrastructure repository
- Harbor backup documented: PostgreSQL `pg_dump` + registry blob PVC snapshot

**Dependencies:** M4-F1 (DefectDojo), M5-F1 (NetworkPolicy for `harbor` namespace), M5-F2 (TLS — Harbor serves over HTTPS by default).

---

### M7-F3: Commit Signing [Optional]

**Delivers:** Git commits are cryptographically signed using SSH keys, providing commit-level integrity verification on GitHub.

**Key Components:**

- Ed25519 SSH key pair dedicated to signing (separate from authentication key)
- Git config: `gpg.format = ssh`, `user.signingkey`, `commit.gpgsign = true`
- Public key added to GitHub as a "Signing Key" (not "Authentication Key")

**Done Criteria:**

- `git config --global commit.gpgsign` returns `true`
- `git log --show-signature -1` shows a valid signature on the latest commit
- `git verify-commit HEAD` succeeds
- GitHub UI shows "Verified" badge on signed commits
- Signing key is a dedicated Ed25519 key, separate from the SSH authentication key
- Signing works without GPG — uses SSH signing only (simpler setup, no GPG keyring management)

**Dependencies:** None (can be done at any time, independent of all other milestones).

---

## Milestone Verification

Run these checks to confirm M7 features are complete (check only the features you chose to implement):

1. **SonarQube (if deployed):** Quality gate on a project passes/fails based on configured thresholds; findings appear in DefectDojo
2. **Harbor (if deployed):** Push an image — Trivy scan runs automatically; robot account can push from CI; tag retention policy is active
3. **Commit signing (if enabled):** `git verify-commit HEAD` succeeds; GitHub shows "Verified" badge

## Reference

- Main document: Tool Details — Section 7 (Harbor, line ~543)
- Main document: Tool Details — Section 9 (SonarQube Community Build, line ~740)
- Main document: Tool Details — Section 12 (Optional: Commit Signing, line ~1052)
- Main document: DefectDojo vs SonarQube — When You Need Which (line ~1074)
- Main document: Phase 4 — Runtime Security and Optional Enhancements (line ~2116)
