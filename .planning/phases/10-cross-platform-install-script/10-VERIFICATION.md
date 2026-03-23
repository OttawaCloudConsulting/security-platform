---
phase: 10-cross-platform-install-script
verified: 2026-03-17T00:00:00Z
status: human_needed
score: 13/14 must-haves verified
human_verification:
  - test: "Run `bash dist/install.sh` on a clean macOS arm64 or Linux machine (or Docker container) without any of the 6 tools pre-installed"
    expected: "All 6 tools install successfully to ~/.local/bin and the summary table shows 'installed' for each"
    why_human: "Cannot execute network downloads in static verification; actual curl/sh pipeline and checksum verification require live network and filesystem"
  - test: "Run `bash dist/install.sh` a second time immediately after a successful first run"
    expected: "Summary table shows 'skipped' for all 6 tools (idempotency) with exit code 0"
    why_human: "Idempotency requires running the script twice against installed binaries; cannot simulate in static check"
  - test: "Confirm INST-05 scope decision: INST-05 requires pre-commit, Semgrep, AND Checkov to install via pipx, but only pre-commit is installed; Semgrep and Checkov are deferred to CI (M2)"
    expected: "Team confirms the INST-05 partial satisfaction is an accepted scope decision, OR REQUIREMENTS.md INST-05 text is narrowed to 'pre-commit installs via pipx' to match actual scope"
    why_human: "REQUIREMENTS.md marks INST-05 complete but the requirement text names three tools; only one is installed. The project team made this decision consciously but the requirement text has not been narrowed."
---

# Phase 10: Cross-Platform Install Script Verification Report

**Phase Goal:** Cross-platform install script for all security tools
**Verified:** 2026-03-17
**Status:** human_needed (all automated checks pass; 3 items need human confirmation)
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

All truths are taken directly from the PLAN frontmatter `must_haves` sections across Plan 01 and Plan 02.

#### Plan 01 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | dist/versions.conf exists with pinned versions for all 6 tools | VERIFIED | File exists at dist/versions.conf; contains PRECOMMIT_VERSION, TRIVY_VERSION, SYFT_VERSION, GRYPE_VERSION, GITLEAKS_VERSION, HADOLINT_VERSION (6 VERSION= lines) |
| 2 | dist/install.sh sources versions.conf and parses -v/--verbose and -h/--help flags | VERIFIED | Line 461: `. "$SCRIPT_DIR/versions.conf"`; lines 449-455: arg parser handles -v/--verbose and -h/--help; `bash dist/install.sh --help` outputs correct usage |
| 3 | install.sh bootstraps pipx if not found and installs pre-commit via pipx | VERIFIED | `ensure_pipx()` at line 173 with PEP 668 fallback; `install_precommit()` at line 206 calls `pipx install "pre-commit==$PRECOMMIT_VERSION"` |
| 4 | install.sh adds ~/.local/bin to PATH for the current session | VERIFIED | Line 471: `export PATH="$INSTALL_DIR:$PATH"` where INSTALL_DIR defaults to `$HOME/.local/bin` |
| 5 | install.sh prints end-of-run summary table with tool name, version, and status | VERIFIED | `print_summary()` at line 44 prints formatted table; called at line 487 in main flow |
| 6 | All bash 3.2 compatibility rules are followed (no associative arrays, no mapfile, no \|&) | VERIFIED | grep scan found zero instances of `declare -A`, `typeset -A`, `mapfile`, `readarray`, `\|&`, or `&>` in install.sh |

#### Plan 02 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 7 | install_trivy downloads Trivy via official install script to ~/.local/bin | VERIFIED | Lines 244/252: `curl -sfL "$TRIVY_INSTALL_URL" \| sh -s -- -b "$INSTALL_DIR" "v${TRIVY_VERSION}"` with verbose toggle |
| 8 | install_syft downloads Syft via official Anchore install script to ~/.local/bin | VERIFIED | Lines 271/279: `curl -sSfL "$SYFT_INSTALL_URL" \| sh -s -- -b "$INSTALL_DIR" "v${SYFT_VERSION}"` |
| 9 | install_grype downloads Grype via official Anchore install script to ~/.local/bin | VERIFIED | Lines 298/306: `curl -sSfL "$GRYPE_INSTALL_URL" \| sh -s -- -b "$INSTALL_DIR" "v${GRYPE_VERSION}"` |
| 10 | install_gitleaks downloads Gitleaks tarball with checksum verification and extracts binary to ~/.local/bin | VERIFIED | Lines 316-366: URL template substitution, checksums.txt download, `verify_sha256` call, `tar -xzf`, `mv` to INSTALL_DIR |
| 11 | install_hadolint downloads hadolint binary with .sha256 checksum verification to ~/.local/bin | VERIFIED | Lines 368-419: URL template substitution, .sha256 download, `verify_sha256` call, `chmod +x`, `mv` to INSTALL_DIR |
| 12 | All 5 binary installers are idempotent (skip if correct version already installed) | VERIFIED | Each installer calls `is_installed <tool> "$<TOOL>_VERSION"` at the top; returns early with "skipped" status if match found |
| 13 | All 5 binary installers use correct per-tool OS/arch naming from the architecture normalization table | VERIFIED | Gitleaks uses `get_gitleaks_os`/`get_gitleaks_arch` (darwin/linux, x64/arm64); hadolint uses `get_hadolint_os`/`get_hadolint_arch` (macos/linux, x86_64/arm64); Trivy/Syft/Grype delegate to official scripts |
| 14 | ROADMAP success criteria updated to reflect 6 tools not 8 | VERIFIED | ROADMAP.md line 163: "installs all 6 security CLI tools (pre-commit, Trivy, Syft, Grype, Gitleaks, hadolint)"; line 165: "pre-commit is installed via pipx... Semgrep and Checkov deferred to CI-only in M2"; plan list at lines 171-172 shows 10-01-PLAN.md and 10-02-PLAN.md |

**Score: 14/14 truths pass automated checks** (3 require human confirmation for runtime behavior)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `dist/versions.conf` | Version manifest with pinned versions and URL templates | VERIFIED | 23 lines; 6 VERSION= keys; 3 install script URLs; 4 URL templates with {VERSION}/{OS}/{ARCH} placeholders; `bash -n` passes |
| `dist/install.sh` | Complete install script with all 6 tool installers (min 300 lines) | VERIFIED | 494 lines; contains all 6 install_ functions; no stub "see Plan 02" text; `bash -n` passes; shellcheck exits 0 at --severity=error |
| `.planning/ROADMAP.md` | Updated Phase 10 success criteria referencing 6 tools | VERIFIED | "6 security CLI tools" at line 163; Semgrep/Checkov deferral noted at line 165; plan list at lines 171-172 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| dist/install.sh | dist/versions.conf | dot/source command | VERIFIED | Line 461: `. "$SCRIPT_DIR/versions.conf"` — exact pattern from PLAN |
| dist/install.sh | pipx install pre-commit | install_precommit function | VERIFIED | Lines 217/225: `pipx install "pre-commit==$PRECOMMIT_VERSION"` |
| dist/install.sh | Trivy official install script | curl -sfL pipe to sh | VERIFIED | Lines 244/252: `curl -sfL "$TRIVY_INSTALL_URL" \| sh -s -- -b "$INSTALL_DIR" "v${TRIVY_VERSION}"` |
| dist/install.sh | GitHub Gitleaks releases | curl download + checksum verify + tar extract | VERIFIED | Lines 338-365: tarball download, checksums.txt parse, verify_sha256, tar -xzf, mv |
| dist/install.sh | GitHub hadolint releases | curl download + checksum verify | VERIFIED | Lines 392-418: binary download, .sha256 download, verify_sha256, chmod +x, mv |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| INST-01 | 10-01, 10-02 | Developer can run install script on macOS or Linux to install all security CLI tools without Homebrew | SATISFIED | install.sh installs via curl/pipx/sh — no Homebrew dependency anywhere in script |
| INST-02 | 10-01, 10-02 | Install script auto-detects OS (macOS/Linux) and architecture (amd64/arm64) for binary downloads | SATISFIED | detect_os()/detect_arch() defined; per-tool normalization functions (get_gitleaks_os, get_hadolint_os, etc.) used in actual installers |
| INST-03 | 10-01 | Tool versions are pinned in a manifest file and install script installs those exact versions | SATISFIED | dist/versions.conf has all 6 pinned versions; install.sh sources it and passes exact versions to each installer |
| INST-04 | 10-01 | Install script verifies PATH includes tool install locations and warns if not configured | SATISFIED | verify_path() at line 425 checks INSTALL_DIR in PATH and warns per-tool if not found; called at line 484 |
| INST-05 | 10-01 | Python CLI tools (pre-commit, Semgrep, Checkov) install via pipx for dependency isolation | PARTIAL — see human verification | pre-commit installs via pipx; Semgrep and Checkov are deferred to CI (M2). REQUIREMENTS.md marks [x] complete but requirement text names three tools; ROADMAP documents the accepted scope reduction. Needs human confirmation. |
| INST-06 | 10-02 | Go binary tools (Trivy, Syft, Grype, Gitleaks) install via official install scripts or direct binary download | SATISFIED | Trivy/Syft/Grype use official curl-pipe install scripts; Gitleaks uses direct tarball download with SHA-256 verification |
| INST-07 | 10-02 | hadolint installs via direct binary download from GitHub releases | SATISFIED | install_hadolint() downloads raw binary from GitHub releases with .sha256 verification |

**Orphaned requirements:** None — all 7 INST requirements claimed in plans are accounted for.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| dist/install.sh | 109-120 | `detect_os()` defined but never called (shellcheck SC2329) | Info | Dead code. Per-tool normalization functions are used instead for Gitleaks/hadolint; Trivy/Syft/Grype delegate to official scripts. No functional impact — the functions were scaffolded for Plan 02 but replaced by per-tool functions. |
| dist/install.sh | 122-133 | `detect_arch()` defined but never called (shellcheck SC2329) | Info | Same as detect_os() — dead code with no functional impact. |

No blocker or warning anti-patterns found. No TODO/FIXME/placeholder comments. No stub implementations remain ("see Plan 02" text absent). shellcheck exits 0 at `--severity=error`.

---

### Human Verification Required

#### 1. End-to-End Install Run

**Test:** On a clean macOS arm64 or Linux machine (or Docker container) with none of the 6 tools present, run `bash dist/install.sh -v`
**Expected:** All 6 tools (pre-commit, trivy, syft, grype, gitleaks, hadolint) install to `~/.local/bin`, each responds to its version command, exit code is 0, and summary table shows "installed" for all 6
**Why human:** Cannot execute network downloads or filesystem operations in static verification; actual curl/sh pipelines, SHA-256 checksum verification, and tar extraction require a live system

#### 2. Idempotency Verification

**Test:** Immediately after a successful install run, run `bash dist/install.sh` a second time
**Expected:** All 6 tools show "skipped" in the summary table (correct version already installed), exit code 0, no reinstallation occurs
**Why human:** Requires the binaries to actually be installed and `is_installed()` to successfully invoke each tool's version command

#### 3. INST-05 Scope Acceptance Confirmation

**Test:** Review INST-05 in REQUIREMENTS.md against actual script behavior
**Expected:** Team confirms that INST-05 is satisfied by pre-commit-only pipx installation (with Semgrep/Checkov deferred to CI in M2), OR narrows the INST-05 requirement text to match actual scope
**Why human:** INST-05 requirement text says "Python CLI tools (pre-commit, Semgrep, Checkov) install via pipx" but only pre-commit is installed. The project team accepted this scope reduction and ROADMAP.md documents the deferral. The requirement text itself should be updated to avoid confusion in future phases — this is a documentation consistency issue, not a functional defect.

---

### Gaps Summary

No functional gaps blocking goal achievement. The phase goal "Cross-platform install script for all security tools" is achieved:

- `dist/versions.conf` correctly pins all 6 tool versions with URL templates
- `dist/install.sh` is a complete, 494-line bash 3.2 compatible script
- All 6 installers are implemented with idempotency checks and error handling
- Checksum verification is present for Gitleaks (checksums.txt) and hadolint (.sha256)
- Trivy/Syft/Grype use official install scripts with built-in verification
- PATH management, verbose mode, summary table, and help flag all work correctly
- ROADMAP.md accurately reflects the 6-tool scope decision
- All 4 commits are verified present in git history

The two dead functions (`detect_os`, `detect_arch`) are a minor code quality issue but do not affect functionality. The INST-05 requirement text inconsistency is a documentation issue to resolve — it does not block phase completion since the scope decision was made intentionally and is documented in ROADMAP.

---

_Verified: 2026-03-17_
_Verifier: Claude (gsd-verifier)_
