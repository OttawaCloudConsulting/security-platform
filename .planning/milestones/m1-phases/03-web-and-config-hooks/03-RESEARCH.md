# Phase 3: Web and Config Hooks - Research

**Researched:** 2026-03-15
**Domain:** ESLint (TypeScript), hadolint (Dockerfile), yamllint (YAML), markdownlint (Markdown) pre-commit hook validation and violation remediation
**Confidence:** HIGH

## Summary

Phase 3 validates four pre-commit hooks already configured in `.pre-commit-config.yaml` (Phase 1): ESLint for TypeScript/JavaScript, hadolint for Dockerfiles, yamllint for YAML, and markdownlint for Markdown. Unlike Phase 2 where hooks worked out-of-the-box, ESLint requires additional setup: installing `eslint`, `@eslint/js`, and `typescript-eslint` as devDependencies and creating an `eslint.config.mjs` flat config file. The other three hooks need only config files (markdownlint) or minor validation (yamllint, hadolint).

The target repo contains 36 TypeScript files (CDK stacks, Lambda handlers, Jest tests), 1 JavaScript file (`jest.config.js` using CommonJS `module.exports`), 1 YAML file (`.pre-commit-config.yaml`), zero Dockerfiles, and approximately 40 non-dot-directory Markdown files. ESLint violation remediation across 36 TS files is the bulk of the work. hadolint has no files to lint (verified: no Dockerfiles exist), so LINT-04 is verified via a temporary Dockerfile test. yamllint with `-d relaxed` on a single YAML file should pass with minimal or no issues. markdownlint across 40+ Markdown files will likely produce many violations requiring a `.markdownlint.json` config and a `.markdownlintignore` file.

**Primary recommendation:** Install ESLint + typescript-eslint, create `eslint.config.mjs` with `recommended` preset, fix all TS violations, then configure markdownlint with appropriate rule disabling and path exclusions. Validate yamllint and hadolint last as they are lowest effort.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Full ESLint install: `eslint` + `@typescript-eslint` as devDependencies in target repo
- Use flat config format (`eslint.config.mjs`) -- modern standard
- Rule preset: `@typescript-eslint/recommended` -- catches type errors, unused vars, any-type abuse without being overly opinionated
- Lint all files including test files (`test/*.test.ts`) -- no exclusions
- Fix all existing violations across 36 TS files -- clean slate, same approach as Phase 2
- Leave hadolint hook configured in `.pre-commit-config.yaml` as a no-op -- zero cost, activates automatically when Dockerfiles are added
- Verify LINT-04 by creating a temporary Dockerfile with a known violation, confirming hadolint catches it, then deleting the temp file
- Keep `-d relaxed` inline in hook args -- no `.yamllintrc` config file
- Only one YAML file in repo (`.pre-commit-config.yaml`), config file would be over-engineering
- Add `.markdownlint.json` config file to disable noisy rules (e.g., line-length MD013, inline HTML MD033) that conflict with tooling-generated markdown
- Add `.markdownlintignore` to exclude all dot-prefixed directories (`.claude/`, `.obsidian/`, `.planning/`, etc.)
- Fix all violations across all linters -- clean slate, consistent with Phase 2 approach
- Suppress with inline annotations only where fixing would change meaningful content or behavior (same Phase 2 pattern)

### Claude's Discretion
- Specific ESLint rules to enable/disable beyond `@typescript-eslint/recommended`
- Specific markdownlint rules to disable in `.markdownlint.json`
- Which dot-prefixed directories to list in `.markdownlintignore`
- Whether `jest.config.js` needs special ESLint treatment (CommonJS in a TS project)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LINT-03 | ESLint hook flags TypeScript/JavaScript linting issues on every commit | ESLint local hook configured in `.pre-commit-config.yaml` with `npx eslint` entry. Requires `eslint`, `@eslint/js`, `typescript-eslint` installed as devDependencies and `eslint.config.mjs` created. 36 TS files + 1 JS file to lint. |
| LINT-04 | hadolint hook flags Dockerfile best practice violations on every commit | hadolint-docker hook configured at rev v2.12.0. No Dockerfiles exist in repo. Verify by creating temp Dockerfile with violation, confirming hook catches it, then removing. |
| LINT-05 | yamllint hook flags YAML/Kubernetes manifest formatting issues on every commit | yamllint hook configured at rev v1.35.1 with `-d relaxed` args. Only 1 YAML file: `.pre-commit-config.yaml`. Run hook to verify it passes or fix any issues. |
| LINT-06 | markdownlint hook flags Markdown style issues on every commit | markdownlint-cli hook configured at rev v0.43.0. ~40 non-dot-directory Markdown files. Requires `.markdownlint.json` config and `.markdownlintignore` to exclude dot directories. |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| eslint | latest | TypeScript/JavaScript linting engine | Industry standard, required by pre-commit local hook (`npx eslint`) |
| @eslint/js | latest | ESLint core recommended rules | Provides `eslint.configs.recommended` for flat config |
| typescript-eslint | latest | TypeScript parser and rules for ESLint | Provides `tseslint.configs.recommended` preset, the standard for TS linting |
| hadolint | v2.12.0 | Dockerfile linting | Already configured in `.pre-commit-config.yaml` via `hadolint-docker` |
| yamllint | v1.35.1 | YAML linting | Already configured in `.pre-commit-config.yaml` with `-d relaxed` |
| markdownlint-cli | v0.43.0 | Markdown style linting | Already configured in `.pre-commit-config.yaml` |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| pre-commit | 4.5.0 | Hook framework | Already installed and activated (Phase 1) |
| typescript | ~5.9.3 | TypeScript compiler | Already in devDependencies, needed by typescript-eslint parser |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `recommended` | `strict` | Strict catches more bugs but is not semver-stable; rules may change between minor versions. Recommended is the safe default. |
| `recommended` | `recommended-type-checked` | Type-checked rules require parserOptions configuration and are slower. Not needed for initial setup. |

**Installation:**
```bash
cd repos/aws-zabbix-monitoring-solution
npm install --save-dev eslint @eslint/js typescript-eslint
```

Note: `typescript` is already in devDependencies at ~5.9.3. No need to install it again.

## Architecture Patterns

### Target File Inventory

```
repos/aws-zabbix-monitoring-solution/
├── bin/
│   └── cdk-zabbix.ts                    # CDK app entry point
├── lib/
│   ├── cdk-zabbix-stack.ts              # Main stack
│   ├── config.ts                        # Configuration loader
│   ├── constructs/
│   │   ├── internal-alb.ts              # ALB construct
│   │   ├── internal-nlb.ts              # NLB construct
│   │   ├── zabbix-server-service.ts     # Fargate service
│   │   └── zabbix-web-service.ts        # Fargate service
│   └── zabbix/
│       ├── admin-password-stack.ts      # 6 nested stacks
│       ├── configuration-stack.ts
│       ├── database-stack.ts
│       ├── ecs-stack.ts
│       ├── monitoring-stack.ts
│       └── tls-bootstrap-stack.ts
├── lambda/
│   ├── set-admin-password/index.ts      # Lambda handlers
│   ├── shared/
│   │   ├── zabbix-api-client.ts
│   │   └── zabbix-is-complete.ts
│   ├── tls-bootstrap/index.ts
│   ├── zabbix-auto-config/index.ts
│   ├── zabbix-host-registration/index.ts
│   └── zabbix-template-import/index.ts
├── test/
│   └── *.test.ts                        # 16 test files
├── jest.config.js                       # CommonJS (module.exports)
├── .pre-commit-config.yaml              # Only YAML file
├── *.md                                 # ~40 Markdown files (docs/, root)
└── (no Dockerfiles)
```

**File counts:**
- TypeScript: 36 files (across `bin/`, `lib/`, `lambda/`, `test/`)
- JavaScript: 1 file (`jest.config.js` -- CommonJS format)
- YAML: 1 file (`.pre-commit-config.yaml`)
- Dockerfile: 0 files
- Markdown: ~40 files in non-dot directories (root, `docs/`, `scripts/dev-certs/`)

### Pattern 1: ESLint Flat Config (`eslint.config.mjs`)

**What:** Modern ESLint configuration using flat config format with typescript-eslint recommended preset.
**When to use:** All new ESLint setups (legacy `.eslintrc` format is deprecated).

```javascript
// eslint.config.mjs
// Source: https://typescript-eslint.io/getting-started/
// @ts-check
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  eslint.configs.recommended,
  tseslint.configs.recommended,
  {
    ignores: ['cdk.out/**', 'node_modules/**'],
  },
);
```

**Key points:**
- Uses `tseslint.config()` helper (provides type safety and config merging)
- `eslint.configs.recommended` enables base JS rules
- `tseslint.configs.recommended` enables TS rules (no-explicit-any, no-unused-vars, etc.)
- Global `ignores` object (with no other keys) excludes directories from linting
- `node_modules` is ignored by default, but `cdk.out` must be explicitly excluded

### Pattern 2: Handling `jest.config.js` (CommonJS in a TS project)

**What:** `jest.config.js` uses `module.exports = { ... }` which is CommonJS. ESLint with typescript-eslint may flag it.
**Recommendation:** The ESLint local hook in `.pre-commit-config.yaml` matches `\.(js|jsx|ts|tsx)$`, so `jest.config.js` WILL be linted. Two options:

1. **Exclude it from ESLint** by adding `'jest.config.js'` to the `ignores` array -- simplest, since it is a trivial config file.
2. **Add a separate config block** for `.js` files that disables TS-specific rules.

**Recommended approach:** Exclude `jest.config.js` in the ignores. It is a 9-line config file that does not benefit from linting.

```javascript
{
  ignores: ['cdk.out/**', 'node_modules/**', 'jest.config.js'],
}
```

### Pattern 3: markdownlint Configuration

**What:** `.markdownlint.json` in repo root configures which rules to enforce.
**When to use:** When default markdownlint rules produce excessive noise on project markdown.

```json
{
  "MD013": false,
  "MD033": false,
  "MD041": false
}
```

Rules to consider disabling:
- **MD013** (line-length): CDK projects have long lines in code blocks and tables. Disabling avoids false positives in documentation.
- **MD033** (inline HTML): Tooling-generated markdown and some documentation uses HTML elements.
- **MD041** (first-line-heading): Some markdown files start with metadata or comments, not headings.

### Pattern 4: markdownlint Ignore File

**What:** `.markdownlintignore` excludes paths from markdownlint scanning.
**When to use:** When dot-prefixed directories contain non-standard markdown.

```
# Dot-prefixed directories with non-standard markdown
.claude/
.obsidian/
.planning/
agents/
node_modules/
cdk.out/
```

### Pattern 5: hadolint Temporary Validation

**What:** Since no Dockerfiles exist, create a temp file to prove the hook works.
**When to use:** LINT-04 verification only.

```bash
cd repos/aws-zabbix-monitoring-solution
# Create Dockerfile with known violation (DL3008: pin versions in apt-get install)
echo 'FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl' > /tmp/test-Dockerfile
cp /tmp/test-Dockerfile Dockerfile
git add Dockerfile
pre-commit run hadolint-docker --files Dockerfile
# Should fail with DL3008 warning
git rm -f Dockerfile
rm /tmp/test-Dockerfile
```

### Pattern 6: Pre-commit Hook Execution

```bash
# Run individual hooks
pre-commit run eslint --all-files
pre-commit run hadolint-docker --all-files
pre-commit run yamllint --all-files
pre-commit run markdownlint --all-files

# Run all hooks
pre-commit run --all-files --show-diff-on-failure
```

### Anti-Patterns to Avoid
- **Using `.eslintrc.js` or `.eslintrc.json`:** Legacy format. Use `eslint.config.mjs` flat config only.
- **Installing `@typescript-eslint/eslint-plugin` and `@typescript-eslint/parser` separately:** The `typescript-eslint` package bundles both. Separate installs are the legacy approach.
- **Adding `--ext .ts` to the ESLint command:** Not needed with flat config. File matching is configured in the config file.
- **Creating `.yamllintrc` for one YAML file:** Over-engineering. Keep `-d relaxed` in hook args.
- **Disabling too many markdownlint rules:** Start with MD013, MD033, and review what the actual violations are before disabling more.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TypeScript linting rules | Custom eslint rules | `@typescript-eslint/recommended` | 50+ rules covering type safety, unused code, any-type abuse |
| Markdown style enforcement | Custom scripts | markdownlint-cli with `.markdownlint.json` | 50+ configurable rules, well-maintained |
| Dockerfile best practices | Shell script checks | hadolint | Parses Dockerfiles into AST, checks against Docker best practices |
| YAML validation | Custom parsers | yamllint with `-d relaxed` | Handles edge cases (multi-line strings, anchors, etc.) |

**Key insight:** All four linters are mature, well-documented tools with pre-commit integration already configured. The work is installation (ESLint), configuration (markdownlint), and violation remediation -- not custom tooling.

## Common Pitfalls

### Pitfall 1: ESLint Cannot Find Config File
**What goes wrong:** Running `npx eslint` fails with "Could not find config file" or similar error.
**Why it happens:** The `eslint.config.mjs` must be in the project root (same directory as `package.json`). If placed elsewhere, ESLint cannot find it.
**How to avoid:** Create `eslint.config.mjs` in `repos/aws-zabbix-monitoring-solution/` (project root, alongside `package.json`).
**Warning signs:** Error message mentioning "no configuration found" or "unable to resolve config".

### Pitfall 2: ESLint Linting `cdk.out/` Generated Files
**What goes wrong:** ESLint attempts to lint auto-generated JavaScript files in `cdk.out/`, producing hundreds of irrelevant errors.
**Why it happens:** `cdk.out/` contains synthesized CloudFormation templates and bundled Lambda code. Without explicit ignores, ESLint processes everything.
**How to avoid:** Add `'cdk.out/**'` to the global `ignores` array in `eslint.config.mjs`.
**Warning signs:** Errors in files with paths like `cdk.out/asset.*/index.js`.

### Pitfall 3: `jest.config.js` CommonJS Errors
**What goes wrong:** ESLint with typescript-eslint flags `module.exports` in `jest.config.js` because the project uses ESM-style TypeScript.
**Why it happens:** `jest.config.js` uses CommonJS (`module.exports = { ... }`), but typescript-eslint expects ESM patterns.
**How to avoid:** Add `'jest.config.js'` to the ESLint ignores. A 9-line config file does not need linting.
**Warning signs:** Errors about `require` or `module.exports` being undefined or unexpected.

### Pitfall 4: markdownlint Scanning Dot Directories
**What goes wrong:** markdownlint scans `.claude/`, `.obsidian/`, `.planning/` and produces hundreds of violations on non-standard markdown (agent prompts, command templates, planning docs).
**Why it happens:** markdownlint-cli traverses all directories by default unless excluded.
**How to avoid:** Create `.markdownlintignore` with all dot-prefixed directories and other non-target directories.
**Warning signs:** Violations in files under `.claude/commands/` or `.obsidian/`.

### Pitfall 5: ESLint `@typescript-eslint/no-require-imports` on `jest.config.js`
**What goes wrong:** The `recommended` config enables `@typescript-eslint/no-require-imports` which flags `require()` calls. If `jest.config.js` is not excluded, this fires.
**Why it happens:** Rule is designed to catch mixed CJS/ESM patterns in TS projects.
**How to avoid:** Exclude `jest.config.js` from ESLint (see Pitfall 3).

### Pitfall 6: ESLint `@typescript-eslint/no-unused-vars` vs TypeScript `noUnusedLocals`
**What goes wrong:** Both ESLint and TypeScript can enforce "no unused variables", creating duplicate warnings.
**Why it happens:** `tsconfig.json` has `noUnusedLocals: false` and `noUnusedParameters: false`, so TypeScript is not checking. ESLint's `@typescript-eslint/no-unused-vars` fills that gap. This is the correct configuration -- ESLint handles it with better error messages.
**How to avoid:** No action needed. The current setup is correct: TS defers to ESLint for unused var checking.

### Pitfall 7: hadolint-docker Requires Docker
**What goes wrong:** The `hadolint-docker` hook entry requires Docker to be installed and running because it pulls the `hadolint/hadolint` Docker image.
**Why it happens:** The pre-commit config uses `hadolint-docker` (not the standalone `hadolint` binary).
**How to avoid:** Ensure Docker is running before testing the hadolint hook. If Docker is not available, the hook will fail with a connection error, not a lint error.
**Warning signs:** Error messages about Docker daemon not running.

## Code Examples

### Installing ESLint Dependencies
```bash
cd repos/aws-zabbix-monitoring-solution
npm install --save-dev eslint @eslint/js typescript-eslint
```

### Creating ESLint Flat Config
```javascript
// eslint.config.mjs
// Source: https://typescript-eslint.io/getting-started/
// @ts-check
import eslint from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  eslint.configs.recommended,
  tseslint.configs.recommended,
  {
    ignores: ['cdk.out/**', 'jest.config.js'],
  },
);
```

### Running ESLint via Pre-commit
```bash
cd repos/aws-zabbix-monitoring-solution
pre-commit run eslint --all-files
```

### Running ESLint Directly (for debugging)
```bash
cd repos/aws-zabbix-monitoring-solution
npx eslint .
# Or for specific files:
npx eslint lib/config.ts
```

### Creating markdownlint Configuration
```json
// .markdownlint.json
{
  "MD013": false,
  "MD033": false,
  "MD041": false
}
```

### Creating markdownlint Ignore File
```
# .markdownlintignore
.claude/
.obsidian/
.planning/
agents/
node_modules/
cdk.out/
```

### Verifying yamllint
```bash
cd repos/aws-zabbix-monitoring-solution
pre-commit run yamllint --all-files
```

### Verifying hadolint (Temporary Dockerfile Test)
```bash
cd repos/aws-zabbix-monitoring-solution
echo 'FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl' > Dockerfile
git add Dockerfile
pre-commit run hadolint-docker --files Dockerfile
# Expected: FAIL with DL3008 (pin versions in apt-get)
git rm -f Dockerfile
```

### Verifying Success Criteria: ESLint Catches Violation
```bash
cd repos/aws-zabbix-monitoring-solution
# Introduce a deliberate violation
echo 'const x: any = 1;' > /tmp/test-eslint.ts
cp /tmp/test-eslint.ts lib/test-eslint-violation.ts
git add lib/test-eslint-violation.ts
pre-commit run eslint --files lib/test-eslint-violation.ts
# Should fail with @typescript-eslint/no-explicit-any
git rm -f lib/test-eslint-violation.ts
rm /tmp/test-eslint.ts
```

## Known Violations to Expect

### TypeScript -- Likely ESLint Findings

The `@typescript-eslint/recommended` preset enables these commonly-triggered rules:

- **`@typescript-eslint/no-explicit-any`:** Flags `any` type annotations. CDK projects sometimes use `any` for CloudFormation construct props. These should be fixed to use proper types or suppressed with `// eslint-disable-next-line @typescript-eslint/no-explicit-any`.
- **`@typescript-eslint/no-unused-vars`:** Flags unused variables, function parameters, and imports. Common in test files where destructured values are partially used.
- **`@typescript-eslint/no-require-imports`:** Flags `require()` calls. Should not appear in TS files (project uses ESM imports). Only risk is `jest.config.js` (excluded).
- **`no-undef`:** Base ESLint rule that may conflict with TypeScript globals. The `tseslint.configs.recommended` should handle this by including `eslint-recommended` overrides.

**Estimate:** Expect 20-100+ violations across 36 TS files. Most will be `no-explicit-any` and `no-unused-vars`. These are straightforward to fix (add types, prefix unused params with `_`).

### Markdown -- Likely markdownlint Findings

Without `.markdownlint.json` config:
- **MD013** (line-length): Nearly every file will fail. CDK documentation has long code blocks and tables.
- **MD033** (inline HTML): Documentation files may use HTML for formatting.
- **MD041** (first-line-heading): Files starting with badges or metadata.
- **MD009** (trailing spaces): Common in any markdown.
- **MD010** (hard tabs): Possibly in code blocks.
- **MD047** (files should end with newline): Common oversight.

With `.markdownlint.json` disabling MD013/MD033/MD041, remaining violations should be minor formatting issues.

### YAML -- Likely yamllint Findings

With `-d relaxed`, yamllint is lenient. The single `.pre-commit-config.yaml` file is well-formatted (committed in Phase 1). Expect zero or near-zero violations.

### Dockerfiles -- No Files to Lint

Zero Dockerfiles in repo. hadolint hook is a no-op. Validation uses temporary file approach.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.eslintrc.js` / `.eslintrc.json` | `eslint.config.mjs` (flat config) | ESLint 9.x (2024) | Legacy format deprecated; flat config is the only supported format going forward |
| Separate `@typescript-eslint/parser` + `@typescript-eslint/eslint-plugin` | Single `typescript-eslint` package | typescript-eslint v8 (2024) | Simplified installation; one package instead of two |
| `--ext .ts,.tsx` CLI flag | File matching in config | ESLint 9.x (2024) | Extensions configured in flat config objects, not CLI flags |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | pre-commit 4.5.0 (hook execution framework) |
| Config file | `repos/aws-zabbix-monitoring-solution/.pre-commit-config.yaml` |
| Quick run command | `cd repos/aws-zabbix-monitoring-solution && pre-commit run eslint --all-files && pre-commit run yamllint --all-files && pre-commit run markdownlint --all-files` |
| Full suite command | `cd repos/aws-zabbix-monitoring-solution && pre-commit run --all-files --show-diff-on-failure` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LINT-03 | ESLint flags TS/JS linting issues on commit | smoke | `cd repos/aws-zabbix-monitoring-solution && pre-commit run eslint --all-files` | N/A (pre-commit built-in) |
| LINT-04 | hadolint flags Dockerfile violations on commit | smoke (manual temp file) | `cd repos/aws-zabbix-monitoring-solution && echo 'FROM ubuntu:22.04\nRUN apt-get install -y curl' > Dockerfile && pre-commit run hadolint-docker --files Dockerfile; git rm -f Dockerfile` | N/A |
| LINT-05 | yamllint flags YAML formatting issues on commit | smoke | `cd repos/aws-zabbix-monitoring-solution && pre-commit run yamllint --all-files` | N/A (pre-commit built-in) |
| LINT-06 | markdownlint flags Markdown style issues on commit | smoke | `cd repos/aws-zabbix-monitoring-solution && pre-commit run markdownlint --all-files` | N/A (pre-commit built-in) |

### Sampling Rate
- **Per task commit:** Run the specific hook(s) relevant to that task with `--all-files`
- **Per wave merge:** `pre-commit run --all-files --show-diff-on-failure`
- **Phase gate:** All 4 hooks pass cleanly on `--all-files`; hadolint verified via temp file test

### Wave 0 Gaps
- [ ] `eslint.config.mjs` -- ESLint flat config file (does not exist yet)
- [ ] `npm install --save-dev eslint @eslint/js typescript-eslint` -- ESLint packages not yet in devDependencies
- [ ] `.markdownlint.json` -- markdownlint config file (does not exist yet)
- [ ] `.markdownlintignore` -- markdownlint ignore file (does not exist yet)

## Open Questions

1. **How many ESLint violations exist across 36 TS files?**
   - What we know: The `@typescript-eslint/recommended` preset will flag `any` types, unused vars, and similar issues. CDK projects commonly use `any` for CloudFormation properties.
   - What's unclear: Exact count until `npx eslint .` is run.
   - Recommendation: Run ESLint after setup, capture full output, then systematically fix. Expect 20-100+ violations, mostly `no-explicit-any` and `no-unused-vars`.

2. **Which markdownlint rules beyond MD013/MD033 need disabling?**
   - What we know: CONTEXT.md locks MD013 and MD033 as examples. Other rules (MD041, etc.) may also fire.
   - What's unclear: Exact violation set until `pre-commit run markdownlint --all-files` is run.
   - Recommendation: Start with MD013 and MD033 disabled, run markdownlint, then disable additional rules only if they produce systematic false positives across many files.

3. **Does `hadolint-docker` work without Docker running?**
   - What we know: The hook uses `hadolint/hadolint` Docker image (per pre-commit config using `hadolint-docker` ID).
   - What's unclear: Whether Docker Desktop is running on the workstation.
   - Recommendation: If Docker is not available, the temp-file test will fail with a Docker error (not a lint error). This is acceptable -- document that Docker must be running for hadolint-docker to work.

## Sources

### Primary (HIGH confidence)
- Target repo file inspection: `package.json`, `tsconfig.json`, `jest.config.js`, `.pre-commit-config.yaml` -- directly read
- [typescript-eslint Getting Started](https://typescript-eslint.io/getting-started/) -- exact flat config setup with `recommended` preset
- [typescript-eslint Shared Configs](https://typescript-eslint.io/users/configs/) -- config options and descriptions
- [ESLint Ignore Files](https://eslint.org/docs/latest/use/configure/ignore) -- flat config ignores pattern documentation
- Phase 2 RESEARCH.md and PLAN.md -- established patterns for this project

### Secondary (MEDIUM confidence)
- markdownlint-cli configuration patterns from [npm docs](https://www.npmjs.com/package/markdownlint) and community guides
- ESLint violation predictions based on knowledge of `@typescript-eslint/recommended` ruleset

### Tertiary (LOW confidence)
- Specific violation counts are estimates. Actual violations must be confirmed by running the hooks.
- markdownlint rule disabling beyond MD013/MD033 needs validation by running the hook.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - ESLint setup is well-documented by typescript-eslint; other tools already configured
- Architecture: HIGH - file inventory confirmed by direct inspection; patterns verified against official docs
- Pitfalls: HIGH - ESLint flat config, jest.config.js handling, and markdownlint ignore patterns are well-documented
- Violation predictions: MEDIUM - based on knowledge of rule sets; actual counts require running hooks

**Research date:** 2026-03-15
**Valid until:** 2026-04-15 (stable tools, pinned versions in `.pre-commit-config.yaml`)
