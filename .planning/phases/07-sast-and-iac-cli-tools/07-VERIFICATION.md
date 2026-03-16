---
phase: 07-sast-and-iac-cli-tools
verified: 2026-03-16T22:00:00Z
status: passed
score: 4/4 must-haves verified
---

# Phase 7: SAST and IaC CLI Tools Verification Report

**Phase Goal:** The static analysis and IaC scanning toolchain is installed and available locally alongside the secrets scanner
**Verified:** 2026-03-16T22:00:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                       | Status     | Evidence                                                                       |
| --- | ----------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------ |
| 1   | `semgrep --version` succeeds and shows a current version    | VERIFIED   | Returns `1.155.0`, exit 0; binary at `/Users/christian/.pyenv/shims/semgrep`   |
| 2   | `checkov --version` succeeds and shows a current version    | VERIFIED   | Returns `3.2.396`, exit 0; binary at `/Library/Frameworks/Python.framework/Versions/3.10/bin/checkov` |
| 3   | `gitleaks version` succeeds and shows a current version     | VERIFIED   | Returns `8.30.0`, exit 0; binary at `/opt/homebrew/bin/gitleaks`               |
| 4   | Main doc has verified version notes for all three tools     | VERIFIED   | Lines 171, 219, 371 in `docs/development-security-stack-option-1.md`          |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact                                    | Expected                                                    | Status     | Details                                                                    |
| ------------------------------------------- | ----------------------------------------------------------- | ---------- | -------------------------------------------------------------------------- |
| `docs/development-security-stack-option-1.md` | Verified version notes for Semgrep, Checkov, and Gitleaks | VERIFIED   | 6 total `Verified:` comments present (3 Phase 6 + 3 Phase 7); commit `995a6fe` added exactly 3 lines |

### Key Link Verification

| From            | To     | Via                                | Status   | Details                                                |
| --------------- | ------ | ---------------------------------- | -------- | ------------------------------------------------------ |
| semgrep binary  | $PATH  | pip install to pyenv Python 3.12   | WIRED    | `which semgrep` → `/Users/christian/.pyenv/shims/semgrep`; version command exits 0 |
| checkov binary  | $PATH  | pip install to system Python 3.10  | WIRED    | `which checkov` → `/Library/Frameworks/Python.framework/Versions/3.10/bin/checkov`; version command exits 0 |
| gitleaks binary | $PATH  | brew install (from Phase 5)        | WIRED    | `which gitleaks` → `/opt/homebrew/bin/gitleaks`; version command exits 0 |

Note: Semgrep resolved to pyenv Python 3.12 (not system Python 3.10 where Checkov lives). This is a documented deviation in the SUMMARY — both tools work correctly on PATH regardless of which Python manages them.

### Requirements Coverage

| Requirement | Source Plan | Description                                                          | Status    | Evidence                                                        |
| ----------- | ----------- | -------------------------------------------------------------------- | --------- | --------------------------------------------------------------- |
| TOOL-04     | 07-01-PLAN  | Semgrep CE is installed and on `$PATH` (`semgrep --version` succeeds) | SATISFIED | `semgrep --version` returns `1.155.0`, exit 0; REQUIREMENTS.md line 38 marked `[x]` |
| TOOL-05     | 07-01-PLAN  | Checkov is installed and on `$PATH` (`checkov --version` succeeds)   | SATISFIED | `checkov --version` returns `3.2.396`, exit 0; REQUIREMENTS.md line 39 marked `[x]` |
| TOOL-06     | 07-01-PLAN  | Gitleaks is installed and on `$PATH` (`gitleaks version` succeeds)   | SATISFIED | `gitleaks version` returns `8.30.0`, exit 0; REQUIREMENTS.md line 40 marked `[x]` |

**Orphaned requirements check:** REQUIREMENTS.md traceability table maps only TOOL-04, TOOL-05, TOOL-06 to Phase 7. No orphaned requirements found.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| None | —    | —       | —        | —      |

The only "placeholder" hit in the main doc (line 1135) is in a documentation paragraph about feature branch semantics — not an implementation anti-pattern.

### Human Verification Required

None. All truths are verifiable programmatically for this phase (CLI tool installation and documentation updates).

### Gaps Summary

No gaps. All four must-have truths are verified:

1. Semgrep v1.155.0 is on PATH and responds to `semgrep --version` with exit 0.
2. Checkov v3.2.396 is on PATH and responds to `checkov --version` with exit 0.
3. Gitleaks v8.30.0 is on PATH and responds to `gitleaks version` with exit 0.
4. The main documentation has all three verified version notes at the correct locations (after each tool's install command), following the Phase 6 pattern. Commit `995a6fe` added exactly 3 lines — no other content was changed.

All three requirements (TOOL-04, TOOL-05, TOOL-06) are satisfied and marked complete in REQUIREMENTS.md.

---

_Verified: 2026-03-16T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
