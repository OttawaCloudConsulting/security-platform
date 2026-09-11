#!/usr/bin/env bash
set -euo pipefail

# detect-python.sh — report whether this repository contains Python
# requirements files.
#
# Writes the discovered paths, one per line, to the list file named by $1
# (default: py-reqs.txt) and logs on BOTH branches: "FOUND n ..." when
# requirements files exist, "SKIP: ..." when none do. Always exits 0 — "no
# Python dependency files in this repo" is a valid answer, not an error, and a
# non-zero exit here would fail the CI guard step on a clean skip.
#
# Pathspec: '*requirements*.txt'. Git's default (non-':(glob)') pathspec
# wildcards already cross '/', so a single leading '*' matches every depth.
# The two wrong forms, both measured (16-RESEARCH Pitfall 9):
#   'requirements*.txt'      -> root-anchored, matches NEITHER root nor nested
#   '**/requirements*.txt'   -> matches nested files ONLY, misses the repo root
# A missed manifest would produce a "SKIP:" line on a repo that really does
# have Python dependencies — a false pass that is invisible in the log. The
# leading wildcard also matches dev-requirements.txt and requirements-test.txt,
# which is desirable: those pin real dependencies too.
#
# Invoked both by .github/workflows/security.yml (SCA-02) and by
# scripts/smoke-scans.sh, so the smoke gate tests the logic CI runs rather
# than a copy of it. Never set the executable bit: invoke as
# `bash scripts/detect-python.sh`, never `./scripts/detect-python.sh`.

LIST_FILE="${1:-py-reqs.txt}"

count=0
files=""

while IFS= read -r path; do
  [ -n "$path" ] || continue
  count=$((count + 1))
  files="${files}${path}"$'\n'
done < <(git ls-files -- '*requirements*.txt')

if [ "$count" -eq 0 ]; then
  echo "SKIP: no requirements*.txt found — Python sub-scan not applicable to this repository"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "found=false" >>"$GITHUB_OUTPUT"
  fi
  exit 0
fi

printf '%s' "$files" >"$LIST_FILE"
echo "FOUND ${count} Python requirements file(s):"
cat "$LIST_FILE"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "found=true" >>"$GITHUB_OUTPUT"
fi
exit 0
