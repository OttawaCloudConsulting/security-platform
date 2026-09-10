# shellcheck shell=bash
# shellcheck disable=SC1090  # SETUP_SH is exported by run-tests.sh at a known path
# tests/test_config_generation.sh — behavioral coverage for DIST-01..05:
# config file generation, hook filtering, hook activation, idempotency, and
# the require_git_repo guard.
#
# Follows the isolation contract documented at the top of run-tests.sh:
# subshells emit via echo (or just write real files to disk — filesystem
# state survives subshell exit, only shell variables/exit status do not), the
# parent shell asserts; `set +e` runs immediately after sourcing; no assert
# helper is ever called inside a subshell. Every git-repo-dependent test uses
# its own mktemp -d directory, explicitly removed at the end of the block.

# extract_hook_block <file> <hook_id>
#
# Prints the YAML lines belonging to a single hook entry (from its
# "      - id: <hook_id>" line up to, but not including, the next
# "      - id:" line or EOF). Used to assert per-hook filter keys without a
# YAML parser.
extract_hook_block() {
  local file="$1" hook_id="$2"
  awk -v want="      - id: ${hook_id}" '
    $0 == want { capture=1; print; next }
    capture && /^      - id:/ { exit }
    capture { print }
  ' "$file"
}

# ---------------------------------------------------------------------------
# DIST-04 — every hook uses types:/types_or:/files: filters
# ---------------------------------------------------------------------------

describe "DIST-04: generated .pre-commit-config.yaml — file-pattern filters"

tmpdir_dist04="$(mktemp -d)"
git -C "$tmpdir_dist04" init -q

(
  source "$SETUP_SH"
  set +e
  # Stub out the network-dependent version resolver — DIST-04 is about the
  # generated filter keys, not GitHub API resolution (already covered
  # elsewhere). Deterministic values avoid flaky/slow network calls.
  # shellcheck disable=SC2329
  resolve_hook_versions() {
    # shellcheck disable=SC2034  # HOOK_VER_PRECOMMIT_TERRAFORM read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_PRECOMMIT_TERRAFORM="v1.105.0"
    # shellcheck disable=SC2034  # HOOK_VER_RUFF read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_RUFF="v0.15.6"
    # shellcheck disable=SC2034  # HOOK_VER_SHELLCHECK read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_SHELLCHECK="v0.11.0.1"
    # shellcheck disable=SC2034  # HOOK_VER_HADOLINT read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_HADOLINT="v2.14.0"
    # shellcheck disable=SC2034  # HOOK_VER_YAMLLINT read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_YAMLLINT="v1.38.0"
    # shellcheck disable=SC2034  # HOOK_VER_MARKDOWNLINT read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_MARKDOWNLINT="v0.48.0"
    # shellcheck disable=SC2034  # HOOK_VER_GITLEAKS read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_GITLEAKS="v8.30.0"
  }
  generate_precommit_config "${tmpdir_dist04}/.pre-commit-config.yaml" > /dev/null 2>&1
) 2>&1

precommit_cfg="${tmpdir_dist04}/.pre-commit-config.yaml"

if [[ -f "$precommit_cfg" ]]; then
  pass "generate_precommit_config produced .pre-commit-config.yaml"

  for hook in terraform_fmt terraform_validate ruff ruff-format shellcheck hadolint yamllint markdownlint eslint npm-audit; do
    block="$(extract_hook_block "$precommit_cfg" "$hook")"
    if printf '%s\n' "$block" | grep -Eq '^\s*(types|types_or|files):'; then
      pass "hook '$hook' has an explicit types:/types_or:/files: filter"
    else
      fail "hook '$hook' is missing a types:/types_or:/files: filter (DIST-04 violation)"
    fi
  done

  gitleaks_block="$(extract_hook_block "$precommit_cfg" "gitleaks")"
  if printf '%s\n' "$gitleaks_block" | grep -Eq '^\s*(types|types_or|files):'; then
    fail "gitleaks hook unexpectedly has a types:/types_or:/files: filter (it scans the diff, not per-file)"
  else
    pass "gitleaks hook intentionally has no file-pattern filter (scans git diff via stages: [pre-push])"
  fi
else
  fail "generate_precommit_config did not produce .pre-commit-config.yaml — cannot check filters"
fi

rm -rf "$tmpdir_dist04"

# ---------------------------------------------------------------------------
# DIST-01 / DIST-02 / DIST-04(gitleakscheck already covered) — full configure
# run drops all 6 expected files
# ---------------------------------------------------------------------------

describe "DIST-01 / DIST-02: configure drops all expected files into target repo"

tmpdir_configure="$(mktemp -d)"
git -C "$tmpdir_configure" init -q

(
  source "$SETUP_SH"
  set +e
  # shellcheck disable=SC2329
  resolve_hook_versions() {
    # shellcheck disable=SC2034  # HOOK_VER_PRECOMMIT_TERRAFORM read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_PRECOMMIT_TERRAFORM="v1.105.0"
    # shellcheck disable=SC2034  # HOOK_VER_RUFF read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_RUFF="v0.15.6"
    # shellcheck disable=SC2034  # HOOK_VER_SHELLCHECK read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_SHELLCHECK="v0.11.0.1"
    # shellcheck disable=SC2034  # HOOK_VER_HADOLINT read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_HADOLINT="v2.14.0"
    # shellcheck disable=SC2034  # HOOK_VER_YAMLLINT read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_YAMLLINT="v1.38.0"
    # shellcheck disable=SC2034  # HOOK_VER_MARKDOWNLINT read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_MARKDOWNLINT="v0.48.0"
    # shellcheck disable=SC2034  # HOOK_VER_GITLEAKS read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_GITLEAKS="v8.30.0"
  }
  generate_all_configs "$tmpdir_configure" > /dev/null 2>&1
) 2>&1

if [[ -f "${tmpdir_configure}/.pre-commit-config.yaml" ]]; then
  pass "DIST-01: .pre-commit-config.yaml exists after configure"
else
  fail "DIST-01: .pre-commit-config.yaml missing after configure"
fi

expected_files=(
  ".pre-commit-config.yaml"
  ".gitleaksignore"
  ".markdownlint.jsonc"
  ".markdownlint-fix.markdownlint.jsonc"
  ".markdownlint-cli2.yaml"
  ".markdownlintignore"
)
missing=""
for f in "${expected_files[@]}"; do
  [[ -f "${tmpdir_configure}/${f}" ]] || missing="${missing} ${f}"
done
if [[ -z "$missing" ]]; then
  pass "DIST-02: all 6 expected config files exist after configure"
else
  fail "DIST-02: missing expected file(s):${missing}"
fi

# ---------------------------------------------------------------------------
# DIST-02 — generate_markdownlintignore specifically: content + skip-if-exists
# ---------------------------------------------------------------------------

describe "DIST-02: generate_markdownlintignore content and idempotency"

mdlintignore="${tmpdir_configure}/.markdownlintignore"
if [[ -f "$mdlintignore" ]]; then
  content="$(cat "$mdlintignore")"
  all_present=true
  for excl in "node_modules/" ".terraform/" ".planning/" ".claude/" "cdk.out/"; do
    case "$content" in
      *"$excl"*) ;;
      *) all_present=false ;;
    esac
  done
  if [[ "$all_present" = true ]]; then
    pass ".markdownlintignore contains all expected directory excludes"
  else
    fail ".markdownlintignore is missing one or more expected excludes: $content"
  fi
else
  fail ".markdownlintignore was not generated — cannot check content"
fi

# Mutate then re-run generate_markdownlintignore directly (not the full
# configure pipeline) to prove it follows write_config's skip-if-exists guard
# on its own, independent of the full-pipeline idempotency test below.
marker_line="# TEST MARKER $$ $(date +%s)"
echo "$marker_line" >> "$mdlintignore"

(
  source "$SETUP_SH"
  set +e
  generate_markdownlintignore "$mdlintignore" > /dev/null 2>&1
) 2>&1

if grep -qF "$marker_line" "$mdlintignore"; then
  pass "generate_markdownlintignore does not overwrite an existing file (skip-if-exists honored)"
else
  fail "generate_markdownlintignore overwrote an existing .markdownlintignore, destroying local content"
fi

rm -rf "$tmpdir_configure"

# ---------------------------------------------------------------------------
# DIST-05 — configure is idempotent: re-run does not clobber modified files
# ---------------------------------------------------------------------------

describe "DIST-05: configure is idempotent across repeated runs"

tmpdir_idempotent="$(mktemp -d)"
git -C "$tmpdir_idempotent" init -q

(
  source "$SETUP_SH"
  set +e
  # shellcheck disable=SC2329
  resolve_hook_versions() {
    # shellcheck disable=SC2034  # HOOK_VER_PRECOMMIT_TERRAFORM read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_PRECOMMIT_TERRAFORM="v1.105.0"
    # shellcheck disable=SC2034  # HOOK_VER_RUFF read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_RUFF="v0.15.6"
    # shellcheck disable=SC2034  # HOOK_VER_SHELLCHECK read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_SHELLCHECK="v0.11.0.1"
    # shellcheck disable=SC2034  # HOOK_VER_HADOLINT read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_HADOLINT="v2.14.0"
    # shellcheck disable=SC2034  # HOOK_VER_YAMLLINT read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_YAMLLINT="v1.38.0"
    # shellcheck disable=SC2034  # HOOK_VER_MARKDOWNLINT read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_MARKDOWNLINT="v0.48.0"
    # shellcheck disable=SC2034  # HOOK_VER_GITLEAKS read by generate_precommit_config() in the sourced setup.sh
    HOOK_VER_GITLEAKS="v8.30.0"
  }
  generate_all_configs "$tmpdir_idempotent" > /dev/null 2>&1
) 2>&1

gitleaksignore="${tmpdir_idempotent}/.gitleaksignore"
idempotency_marker="# USER-ADDED SUPPRESSION $$ $(date +%s)"
if [[ -f "$gitleaksignore" ]]; then
  echo "$idempotency_marker" >> "$gitleaksignore"
else
  fail "DIST-05 setup: first configure run did not create .gitleaksignore — cannot test idempotency"
fi

second_run_out=$(
  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329
    resolve_hook_versions() {
      # shellcheck disable=SC2034  # HOOK_VER_PRECOMMIT_TERRAFORM read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_PRECOMMIT_TERRAFORM="v1.105.0"
      # shellcheck disable=SC2034  # HOOK_VER_RUFF read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_RUFF="v0.15.6"
      # shellcheck disable=SC2034  # HOOK_VER_SHELLCHECK read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_SHELLCHECK="v0.11.0.1"
      # shellcheck disable=SC2034  # HOOK_VER_HADOLINT read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_HADOLINT="v2.14.0"
      # shellcheck disable=SC2034  # HOOK_VER_YAMLLINT read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_YAMLLINT="v1.38.0"
      # shellcheck disable=SC2034  # HOOK_VER_MARKDOWNLINT read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_MARKDOWNLINT="v0.48.0"
      # shellcheck disable=SC2034  # HOOK_VER_GITLEAKS read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_GITLEAKS="v8.30.0"
    }
    generate_all_configs "$tmpdir_idempotent"
    echo "rc=$?"
  ) 2>&1
)

assert_contains "$second_run_out" "rc=0" "second configure run exits 0 (no error on already-configured repo)"

if [[ -f "$gitleaksignore" ]] && grep -qF "$idempotency_marker" "$gitleaksignore"; then
  pass "DIST-05: second configure run did not overwrite user-modified .gitleaksignore"
else
  fail "DIST-05: second configure run overwrote .gitleaksignore, destroying the user's local marker line"
fi

assert_contains "$second_run_out" "already exist" "second configure run reports no new files created"

rm -rf "$tmpdir_idempotent"

# ---------------------------------------------------------------------------
# DIST-01/05 supporting — require_git_repo guard
# ---------------------------------------------------------------------------

describe "require_git_repo guard: configure outside a git repository"

tmpdir_notgit="$(mktemp -d)"
# Deliberately NOT git-init'd — and guard against the (unlikely) case that
# this tmpdir sits inside an ancestor git repo, which would make
# `git rev-parse --is-inside-work-tree` succeed for the wrong reason.
if git -C "$tmpdir_notgit" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  fail "require_git_repo test setup invalid: $tmpdir_notgit is unexpectedly inside a git work tree"
else
  notgit_out=$(cd "$tmpdir_notgit" && /bin/bash "$SETUP_SH" configure 2>&1)
  notgit_rc=$?
  assert_contains "$notgit_out" "Not inside a git repository" "configure outside a git repo prints the require_git_repo error"
  assert_status 1 "$notgit_rc" "configure outside a git repo exits non-zero"
fi

rm -rf "$tmpdir_notgit"

# ---------------------------------------------------------------------------
# DIST-03 — activate_hooks wires pre-commit + pre-push hook scripts
# ---------------------------------------------------------------------------

describe "DIST-03: activate_hooks installs pre-commit and pre-push git hooks"

if ! command -v pre-commit > /dev/null 2>&1; then
  echo "  skip  pre-commit not installed on PATH — cannot exercise activate_hooks (mirrors shellcheck skip pattern)"
else
  tmpdir_hooks="$(mktemp -d)"
  git -C "$tmpdir_hooks" init -q

  (
    source "$SETUP_SH"
    set +e
    # shellcheck disable=SC2329
    resolve_hook_versions() {
      # shellcheck disable=SC2034  # HOOK_VER_PRECOMMIT_TERRAFORM read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_PRECOMMIT_TERRAFORM="v1.105.0"
      # shellcheck disable=SC2034  # HOOK_VER_RUFF read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_RUFF="v0.15.6"
      # shellcheck disable=SC2034  # HOOK_VER_SHELLCHECK read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_SHELLCHECK="v0.11.0.1"
      # shellcheck disable=SC2034  # HOOK_VER_HADOLINT read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_HADOLINT="v2.14.0"
      # shellcheck disable=SC2034  # HOOK_VER_YAMLLINT read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_YAMLLINT="v1.38.0"
      # shellcheck disable=SC2034  # HOOK_VER_MARKDOWNLINT read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_MARKDOWNLINT="v0.48.0"
      # shellcheck disable=SC2034  # HOOK_VER_GITLEAKS read by generate_precommit_config() in the sourced setup.sh
      HOOK_VER_GITLEAKS="v8.30.0"
    }
    generate_precommit_config "${tmpdir_hooks}/.pre-commit-config.yaml" > /dev/null 2>&1
    activate_hooks "$tmpdir_hooks" > /dev/null 2>&1
  ) > /dev/null 2>&1

  precommit_hook="${tmpdir_hooks}/.git/hooks/pre-commit"
  prepush_hook="${tmpdir_hooks}/.git/hooks/pre-push"

  if [[ -f "$precommit_hook" && -x "$precommit_hook" ]]; then
    pass "DIST-03: .git/hooks/pre-commit exists and is executable after activate_hooks"
  else
    fail "DIST-03: .git/hooks/pre-commit missing or not executable after activate_hooks"
  fi

  if [[ -f "$prepush_hook" && -x "$prepush_hook" ]]; then
    pass "DIST-03: .git/hooks/pre-push exists and is executable after activate_hooks"
  else
    fail "DIST-03: .git/hooks/pre-push missing or not executable after activate_hooks"
  fi

  rm -rf "$tmpdir_hooks"
fi
