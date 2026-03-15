# Codebase Structure

**Analysis Date:** 2026-03-15

## Directory Layout

```
security_solution/
├── docs/                       # Primary documentation and references
│   ├── adr/                    # Architectural Decision Records (ADR-001 to ADR-014)
│   ├── milestone-plan/         # Phased implementation milestones (1-7)
│   ├── development-security-stack-option-1.md  # Primary document (~2,300 lines)
│   └── ARCHITECTURE_AND_DESIGN.md              # Extracted architecture reference
├── cicd/                       # CI/CD automation scripts
│   ├── pre-commit.sh           # Git pre-commit hook entry point
│   └── lint-markdown.sh        # Markdown linting (two-pass: fix + enforce)
├── temp/                       # Working/analysis files
│   └── red-team/               # Three-agent red-team analysis and consolidated findings
├── .planning/                  # GSD planning artifacts (gitignored)
│   └── codebase/               # Codebase mapping documents
├── CLAUDE.md                   # Project instructions for Claude Code
├── .markdownlint.jsonc         # Markdown lint rules (enforced)
├── .markdownlint-fix.markdownlint.jsonc  # Markdown auto-fix rules
├── .markdownlint-cli2.yaml     # markdownlint-cli2 config (disabled rules)
└── mdl_style_default.rb        # Legacy markdownlint Ruby style config
```

## Directory Purposes

**docs/:**
- Purpose: All published documentation — the primary deliverable of this project
- Contains: Markdown documents, architecture references, milestone plans
- Key files: `development-security-stack-option-1.md` (primary artifact), `ARCHITECTURE_AND_DESIGN.md`
- Subdirectories: `adr/` (14 decision records), `milestone-plan/` (7 milestones)

**docs/adr/:**
- Purpose: Architectural Decision Records responding to red-team findings
- Contains: `adr001-*.md` through `adr014-*.md`, plus `README.md` index
- Key files: `README.md` (index table with status)
- Policy: Append-only — add new records, never modify accepted ones

**docs/milestone-plan/:**
- Purpose: Phased implementation roadmap for the security stack
- Contains: `milestone-1-workstation.md` through `milestone-7-optional.md`, plus `README.md`
- Key files: `README.md` (milestone overview and sequencing)

**cicd/:**
- Purpose: CI/CD automation and linting scripts
- Contains: Shell scripts for pre-commit hooks and markdown linting
- Key files: `pre-commit.sh` (hook entry point), `lint-markdown.sh` (two-pass linter)

**temp/:**
- Purpose: Working files and analysis artifacts
- Contains: Red-team analysis reports
- Subdirectories: `red-team/` (3 perspective reports + consolidated findings)

## Key File Locations

**Entry Points:**
- `cicd/pre-commit.sh`: Git pre-commit hook — lints staged `.md` files, auto-fixes, re-stages
- `cicd/lint-markdown.sh`: Markdown linter — two-pass (auto-fix then enforce)

**Configuration:**
- `.markdownlint.jsonc`: Enforced lint rules (MD001, MD009, MD010, MD025, MD034)
- `.markdownlint-fix.markdownlint.jsonc`: Auto-fixable rule config
- `.markdownlint-cli2.yaml`: Disabled rules with rationale comments
- `CLAUDE.md`: Project instructions for Claude Code sessions

**Core Content:**
- `docs/development-security-stack-option-1.md`: Primary document — full security stack blueprint
- `docs/ARCHITECTURE_AND_DESIGN.md`: Architecture reference extracted from primary document
- `docs/adr/`: Decision records (ADR-001 through ADR-014)

**Analysis:**
- `temp/red-team/00-consolidated-findings.md`: Synthesized red-team findings
- `temp/red-team/01-attacker-perspective.md`: Attacker analysis
- `temp/red-team/02-operator-perspective.md`: Operator analysis
- `temp/red-team/03-architect-perspective.md`: Architect analysis

## Naming Conventions

**Files:**
- `kebab-case.md`: All markdown documents
- `adrNNN-short-description.md`: ADR records with zero-padded 3-digit number
- `milestone-N-short-name.md`: Milestone plan documents
- `NN-description.md`: Red-team reports with numeric prefix for ordering

**Directories:**
- `kebab-case`: All directories (e.g., `red-team/`, `milestone-plan/`)
- Singular for purpose-named dirs (`docs/`, `cicd/`, `temp/`)

**Special Patterns:**
- `README.md`: Index/overview file in directories with multiple documents
- `CLAUDE.md`: Project root instructions
- `UPPERCASE.md`: Project-level important files

## Where to Add New Code

**New ADR:**
- File: `docs/adr/adrNNN-short-description.md` (next number after ADR-014)
- Update: `docs/adr/README.md` index table
- Policy: Never modify accepted ADRs

**New Milestone Plan:**
- File: `docs/milestone-plan/milestone-N-short-name.md`
- Update: `docs/milestone-plan/README.md`

**New CI/CD Script:**
- File: `cicd/script-name.sh`
- Integration: Reference from `cicd/pre-commit.sh` or `.git/hooks/pre-commit`

**New Lint Configuration:**
- File: Root directory `.markdownlint*.jsonc` or `.markdownlint*.yaml`
- Integration: Reference from `cicd/lint-markdown.sh` via `--config` flag

**New Analysis/Working Documents:**
- File: `temp/topic-name/` directory
- Note: `temp/` is for working artifacts, not published content

## Special Directories

**.planning/:**
- Purpose: GSD planning artifacts (codebase maps, project state)
- Source: Auto-generated by GSD codebase mapper agents
- Committed: No (gitignored)

**docs/adr/:**
- Purpose: Append-only architectural decision records
- Source: Authored in response to red-team findings
- Committed: Yes
- Policy: Never modify accepted records; supersede with new ADR if needed

---

*Structure analysis: 2026-03-15*
*Update when directory structure changes*
