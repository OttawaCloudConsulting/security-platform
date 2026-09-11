#!/usr/bin/env bash
set -euo pipefail

# detect-npm.sh — report whether this repository contains npm lockfiles.
#
# Writes the discovered paths, one per line, to the list file named by $1
# (default: npm-lockfiles.txt) and logs on BOTH branches: "FOUND n ..." when
# lockfiles exist, "SKIP: ..." when none do. Always exits 0 — "no npm in this
# repo" is a valid answer, not an error, and a non-zero exit here would fail
# the CI guard step on a clean skip.
#
# Pathspec: '*package-lock.json'. Git's default (non-':(glob)') pathspec
# wildcards already cross '/', so a single leading '*' matches every depth.
# The two wrong forms, both measured (16-RESEARCH Pitfall 9):
#   'package-lock.json'      -> root-anchored, matches nothing in a subdirectory
#   '**/package-lock.json'   -> matches nested files ONLY, misses the repo root
# A missed manifest would produce a "SKIP:" line on a repo that really does
# have npm dependencies — a false pass that is invisible in the log.
#
# Invoked both by .github/workflows/security.yml (SCA-01) and by
# scripts/smoke-scans.sh, so the smoke gate tests the logic CI runs rather
# than a copy of it. Never set the executable bit: invoke as
# `bash scripts/detect-npm.sh`, never `./scripts/detect-npm.sh`.

LIST_FILE="${1:-npm-lockfiles.txt}"

count=0
files=""

# The one legitimate `|| true` here: `grep -v` exits 1 when its input is empty,
# and under `set -o pipefail` that would abort the detector on a repository
# with no lockfiles at all. grep's rc=1 means "no match", not "error". This
# `|| true` is on the discovery pipeline only — never on a branch that decides
# whether files were found.
while IFS= read -r path; do
  [ -n "$path" ] || continue
  count=$((count + 1))
  files="${files}${path}"$'\n'
done < <(git ls-files -- '*package-lock.json' |
  grep -v -e '/node_modules/' -e '^node_modules/' || true)

if [ "$count" -eq 0 ]; then
  echo "SKIP: no package-lock.json found — npm sub-scan not applicable to this repository"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "found=false" >>"$GITHUB_OUTPUT"
  fi
  exit 0
fi

printf '%s' "$files" >"$LIST_FILE"
echo "FOUND ${count} npm lockfile(s):"
cat "$LIST_FILE"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "found=true" >>"$GITHUB_OUTPUT"
fi
exit 0
