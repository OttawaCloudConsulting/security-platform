# Coding Conventions

**Analysis Date:** 2026-03-15

## Project Type

This is a **documentation-focused project** with supporting shell scripts for CI/CD and linting. There is no application code (TypeScript, Python, Go, etc.). Conventions are scoped to:
- Markdown document structure and style
- Shell script (bash) coding patterns
- YAML configuration files for linting
- Documentation metadata (ADR records, code blocks)

---

## Naming Patterns

**Files:**
- Markdown documents: `kebab-case.md` (e.g., `development-security-stack-option-1.md`, `adr001-remove-continue-on-error.md`)
- Shell scripts: `kebab-case.sh` (e.g., `lint-markdown.sh`, `pre-commit.sh`)
- YAML config: `.filename.jsonc` or `.filename.yaml` for hidden configs (e.g., `.markdownlint.jsonc`, `.markdownlint-cli2.yaml`)
- ADR records: `adr###-kebab-case.md` format with leading zero-padded numbers (e.g., `adr001-`, `adr014-`)

**Directories:**
- ADR records: `docs/adr/` — append-only, one file per decision
- Milestone planning: `docs/milestone-plan/` — phase-based tracking
- CI/CD scripts: `cicd/` — automation and linting orchestration
- Draft content: `drafts/` — in-progress section rewrites

**Functions in shell scripts:**
- Snake_case for function names (bash convention)
- Example: `get_repo_root()`, `run_lint_cmd()`

**Variables in shell scripts:**
- UPPERCASE for constants and exported variables: `REPO_ROOT`, `LINT_CMD`, `IGNORE_DOT_DIRS`
- lowercase for local/loop variables: `files`, `pattern`, `f`
- Boolean flags use `true`/`false` strings, not 0/1

---

## Code Style

### Markdown

**Formatting:**
- No hard line wrapping at 80 characters. Lines wrap naturally at document width.
- Prose paragraphs may span multiple physical lines; do not enforce character limits on technical explanations.
- Tables use compact pipe syntax (no padding spaces) for consistency across skill files and references.
  - Example: `| ADR | Title | Date |` not `| ADR | Title | Date |` with spaces
- Fenced code blocks use triple backticks with language identifier where meaningful.
- Blank lines separate major sections; single blank lines between paragraphs within sections.

**Heading Structure:**
- One H1 per document (`# Title`)
- Duplicate heading names under different parent headings are intentional (ADR records reuse `### Context`, `### Decision`, `### Consequences`)
- Headings NOT surrounded by blank lines in some files (intentional structural choice in ADRs and drafts)

**Emphasis:**
- Bold (`**text**`) used for inline labels and structural emphasis, not as heading substitutes
- Italics (`*text*`) rare; use bold for importance

**Code Blocks in Prose:**
- Mixed content blocks (pseudocode, output, mixed languages) are NOT language-tagged
- Real runnable examples include language specifier (bash, python, typescript, etc.)
- Code blocks may not be surrounded by blank lines in some contexts (MD031 disabled in linter config)

**Lists:**
- Ordered lists use explicit numbering for continuation after nested content (e.g., `3. 4.` after a nested block)
- Unordered lists use `-` (hyphen)
- Lists may not be surrounded by blank lines in some files (intentional, MD032 disabled)

### Shell Scripts

**Shebang:**
```bash
#!/usr/bin/env bash
```

**Error Handling:**
- Use `set -euo pipefail` at top of scripts:
  - `-e`: exit on any error
  - `-u`: error on undefined variables
  - `-o pipefail`: pipeline fails if any command fails
- Exit codes: 0 for success, 1 for general errors
- Use `|| true` only for truly non-critical steps (artifact uploads, logging)
- Use `|| exit 1` to fail immediately on critical errors

**Variable Declaration:**
```bash
# File scope constants (UPPERCASE)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Loop/local variables (lowercase)
files=$(git diff --cached --name-only)
for f in $files; do
  # process
done
```

**Conditionals:**
- Use `[[ ]]` (bash-specific) instead of `[ ]` (POSIX) for clarity
- Use `-n` to test non-empty string: `[[ -n "$var" ]]`
- Use `-z` to test empty: `[[ -z "$var" ]]`
- Example: `if [[ -n "$TARGET_FILE" ]]; then`

**Quoting:**
- Quote variables: `"$var"` not `$var`
- Quote command substitutions: `"$(command)"` not `$(command)`
- Unquoted only for deliberate word-splitting (rare)

**Comments:**
- Use `#` for comments (never `#!` outside shebang)
- Comment non-obvious logic. Self-explanatory code needs no comment.
- Example from `lint-markdown.sh`:
  ```bash
  # Pass 1: auto-fix safe rules (unless --no-fix)
  if [[ "$NO_FIX" == false ]]; then
  ```

**Functions:**
```bash
# Name uses snake_case
function get_repo_root() {
  echo "$(cd "$(dirname "$0")/.." && pwd)"
}

# Usage
REPO_ROOT="$(get_repo_root)"
```

**Shellcheck Directives:**
- Use `# shellcheck disable=SC2086` for intentional unquoted expansion
- Example: `$LINT_CMD` (tool name variable) is intentionally unquoted to allow arguments to split
- Comment explains the intent

---

## Import Organization

**Not applicable** — this is a documentation project with shell scripts, not a programming language with imports.

**YAML/Configuration includes:**
- Config file references are inline (e.g., `--config "${REPO_ROOT}/.markdownlint-fix.markdownlint.jsonc"`)
- Paths always use variables for repo root to enable portable scripts

---

## Error Handling

**Shell Scripts:**

**Pattern 1: Exit immediately on error**
```bash
set -euo pipefail
# Any command that returns non-zero exits the script
```

**Pattern 2: Allow non-critical steps to fail silently**
```bash
$LINT_CMD ... || true
```
Used for: SARIF uploads, artifact uploads, reporting infrastructure. Not for security scanning or validation steps.

**Pattern 3: Explicit error exit for critical steps**
```bash
bash "${REPO_ROOT}/cicd/lint-markdown.sh" "$f" || exit 1
```
Used for: Markdown linting in pre-commit hook, security gates, validation.

**Pattern 4: Check command existence before running**
```bash
if command -v markdownlint-cli2 &>/dev/null; then
  LINT_CMD="markdownlint-cli2"
else
  LINT_CMD="npx --yes markdownlint-cli2@0.21.0"
fi
```
Allows fallback to npm install if tool not found locally.

---

## Logging

**Framework:** `bash` native `echo` and `>&2` redirection for stderr

**Patterns:**
- Status messages to stdout: `echo "==> Message"`
- Errors to stderr: `echo "Error: message" >&2`
- Example from `lint-markdown.sh`:
  ```bash
  echo "==> Auto-fixing: ${PATTERN}"  # stdout
  echo "Unknown argument: $1" >&2      # stderr
  ```
- Script output prefixed with `==>` for visibility in logs

---

## Comments

**When to Comment:**

**DO comment:**
- Why a rule is disabled in linter config: See `.markdownlint-cli2.yaml` — every disabled rule has a multi-line explanation of why it's disabled
  - Example: "MD013 - Line length: prose paragraphs... are intentionally not hard-wrapped"
- Non-obvious control flow or conditionals
- Purpose of a code block in context

**DON'T comment:**
- Self-explanatory variable names: `TARGET_FILE="$1"` needs no comment
- Obvious loops: `for f in $files; do` is clear
- Simple assignments

**Multi-line explanations in config files:**
```yaml
# MD024 - No duplicate heading content
# Every ADR entry reuses ### Context, ### Decision, ### Consequences under
# its unique ## ADR-NNN parent heading. Standard ADR format — structural,
# not ambiguous.
MD024: false
```

---

## Documentation Metadata

**ADR Records (`docs/adr/`):**
- Format: Append-only, one file per decision
- Structure (required):
  ```
  # ADR-NNN: Title (max ~60 chars)

  **Status:** Accepted | Proposed | Rejected | Superseded
  **Date:** YYYY-MM-DD
  **Addresses:** [What finding/issue this ADR responds to]

  ## Context
  [Situation and problem statement]

  ## Decision
  [What was decided]

  ## Consequences
  [Positive and negative outcomes]
  ```
- Modification rule: ADR files are **append-only**. Do not modify accepted ADRs; create a new Superseded ADR if decision changes.
- Example: `docs/adr/adr001-remove-continue-on-error.md`

**Primary Document Structure:**
- Main blueprint: `docs/development-security-stack-option-1.md` (~2,300 lines)
- Contains: Copy-pasteable configs, ASCII architecture diagrams, tool comparison tables
- Sections preserved during editing: 4-phase layered structure (Workstation → CI/CD → K8s Infrastructure → Runtime)
- Tone: Reference documentation (factual, prescriptive, not narrative)

---

## Architecture-Specific Conventions

**Diagram Format:**
- ASCII box diagrams (not image files) for portability and version control
- Double-line borders for container grouping: `┌──┐` and `└──┘`
- Logical flow top-to-bottom, left-to-right
- Tools grouped by functional layer (Workstation linting, CI security gates, K8s dashboards)

**Table Format:**
- Pipe-delimited, compact (no padding): `| A | B |` not `| A | B |`
- Column alignment: Name | Version | License | Details
- Example: Tool selection summary matrix in main blueprint

---

## Configuration File Conventions

**Linter Config Files:**

**`.markdownlint.jsonc`** (enforce rules):
- JSON with comments (JSONC format)
- Keys: Rule IDs (MD001, MD009, etc.)
- Values: `false` to disable
- Purpose: Enforce real issues (spacing, URLs, tabs, heading levels)

**`.markdownlint-fix.markdownlint.jsonc`** (auto-fix rules):
- Subset of rules that are safe to auto-fix
- `"default": false` then enable only fixable rules
- Purpose: Fix formatting issues silently before reporting

**`.markdownlint-cli2.yaml`** (detailed explanations):
- YAML, not JSON (more readable for long comments)
- Maps each disabled rule to explanation
- Purpose: Document why rules don't apply to this project
- Updated when new rules are disabled with rationale

---

## Special Files and Locations

**Directories:**
- `.claude/` — Claude agent instructions and GSD framework (generated, not committed directly)
- `.git/hooks/` — Git pre-commit hook calls `cicd/pre-commit.sh`
- `cicd/` — Linting automation scripts
- `docs/adr/` — Architectural decision records (append-only)
- `drafts/` — Rejected or in-progress content (not final)
- `temp/` — Temporary analysis files

**Git Hooks:**
- `pre-commit` (actual, executable) — calls `bash cicd/pre-commit.sh`
- Lints only staged `.md` files
- Auto-fixes and re-stages changes before commit

---

## Where to Add New Content

**New Analysis or Decision:**
- Create file: `docs/adr/adr###-kebab-case-title.md`
- Use ADR template (see above)
- Add entry to `docs/adr/README.md` index

**New Milestone or Planning Content:**
- Create file: `docs/milestone-plan/milestone-#-name.md`
- Structure: Consistent with existing milestones

**Updates to Main Blueprint:**
- File: `docs/development-security-stack-option-1.md`
- Preserve architecture diagram and 4-layer structure
- Update inline code examples and tool configs as needed

**New Script or Tool:**
- Location: `cicd/` for automation
- Use bash, follow shell conventions above
- Add shebang, error handling, comments for non-obvious logic

**Draft Content (Experimental):**
- Location: `drafts/` — explicitly temporary
- Not part of final documentation
- Can be deleted or moved to final location

---

*Convention analysis: 2026-03-15*
