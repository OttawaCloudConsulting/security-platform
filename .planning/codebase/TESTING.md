# Testing Patterns

**Analysis Date:** 2026-03-15

## Test Framework

This is a documentation project, not buildable software. There is no unit test framework. Validation is performed through **shell-script linting pipelines** and **pre-commit hooks**.

**Runner:**
- markdownlint-cli2 v0.21.0 (markdown validation)
- shellcheck (shell script static analysis, referenced in scripts)
- No unit test framework (Jest, Vitest, etc.) — not applicable

**Run Commands:**
```bash
bash cicd/pre-commit.sh                        # Lint staged .md files (pre-commit)
bash cicd/lint-markdown.sh --recursive         # Lint all .md files recursively
bash cicd/lint-markdown.sh README.md           # Lint a single file
bash cicd/lint-markdown.sh --no-fix            # Skip auto-fix, report only
```

## Test File Organization

**Location:**
- `cicd/lint-markdown.sh`: Primary linting script (two-pass)
- `cicd/pre-commit.sh`: Pre-commit hook entry point
- `.git/hooks/pre-commit`: Git hook that calls `cicd/pre-commit.sh`

**No separate test directory** — validation is inline via CI/CD scripts.

## Test Structure

### Markdown Linting (Two-Pass)

The linting pipeline uses a three-tier rule handling approach:

1. **Ignored rules** — Disabled in `.markdownlint-cli2.yaml` (never checked)
2. **Auto-fix rules** — Enabled in `.markdownlint-fix.markdownlint.jsonc` (fixed silently in Pass 1)
3. **Error rules** — Enforced in `.markdownlint.jsonc` (reported in Pass 2)

**Pass 1 (Auto-fix):**
```bash
markdownlint-cli2 --config .markdownlint-fix.markdownlint.jsonc --fix "PATTERN" "#.*/**"
```

**Pass 2 (Enforce):**
```bash
markdownlint-cli2 --config .markdownlint.jsonc "PATTERN" "#.*/**"
```

### Pre-Commit Hook Flow

1. Git hook (`.git/hooks/pre-commit`) calls `bash cicd/pre-commit.sh`
2. `pre-commit.sh` gets staged `.md` files via `git diff --cached`
3. Excludes dot-directory files (`.claude/`, `.obsidian/`, etc.)
4. For each file: runs `lint-markdown.sh` (fix + enforce), then `git add` to re-stage fixes
5. If any lint error remains, commit is blocked

## Configuration Files

**`.markdownlint-cli2.yaml`** — Master config, disables rules that are false positives:
- MD013 (line length) — prose not hard-wrapped by design
- MD022 (heading blank lines) — stylistic, pervasive
- MD024 (duplicate headings) — ADR format reuses headings
- MD029 (ordered list prefix) — explicit numbering is intentional
- MD031 (code block blank lines) — structural choice
- MD032 (list blank lines) — minor formatting
- MD036 (emphasis as heading) — bold used for structural labels
- MD040 (code block language) — many blocks are pseudocode/mixed
- MD060 (table column style) — compact tables are intentional
- MD018 (heading space) — false positive on shebangs

**`.markdownlint.jsonc`** — Enforced rules (errors block commit):
- MD001: Heading increment (no skipping levels)
- MD009: No trailing spaces
- MD010: No hard tabs
- MD025: Single H1 per document
- MD034: No bare URLs

**`.markdownlint-fix.markdownlint.jsonc`** — Rules that can be auto-fixed silently.

## Exclusion Patterns

- Dot-directories excluded at two levels:
  - `cicd/pre-commit.sh`: `grep -v '^\.'` filters staged files from dot-dirs
  - `cicd/lint-markdown.sh`: `#.*/**` ignore glob passed to markdownlint-cli2
- Both exclusions cover `.git/`, `.claude/`, `.obsidian/`, etc.

## Coverage

**Requirements:**
- No code coverage target (not a software project)
- All committed `.md` files outside dot-directories must pass lint
- Pre-commit hook enforces this on every commit

**What's validated:**
- Heading structure (increment, single H1)
- Whitespace (trailing spaces, hard tabs)
- URL formatting (no bare URLs)
- Auto-fixable formatting issues (fixed silently)

## Common Patterns

**Adding a new lint rule:**
1. Add rule to `.markdownlint.jsonc` (enforced) or `.markdownlint-fix.markdownlint.jsonc` (auto-fix)
2. To disable a rule: add to `.markdownlint-cli2.yaml` with rationale comment
3. Test with `bash cicd/lint-markdown.sh --recursive`

**Skipping auto-fix for debugging:**
```bash
bash cicd/lint-markdown.sh --no-fix --recursive
```

**Tool auto-install:**
Scripts use `npx --yes markdownlint-cli2@0.21.0` as fallback if `markdownlint-cli2` is not globally installed.

---

*Testing analysis: 2026-03-15*
*Update when test patterns change*
